import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_config.dart';
import 'call_model.dart';
import 'call_platform.dart';
import 'sdp_utils.dart';

/// What the call UI should currently show.
enum CallPhase {
  /// We are calling; the other side is ringing.
  outgoing,

  /// Someone is calling us and we haven't answered yet.
  incoming,

  /// Accepted; the media path is being established.
  connecting,
  connected,

  /// The network dropped mid-call and we're trying to recover.
  reconnecting,
  ended,
}

/// One 1:1 WebRTC call, signaled through `calls/{callId}` in Firestore.
///
/// Signaling protocol:
/// * The caller owns every offer (`offer: {sdp, type, rev}`), including ICE
///   restarts, so there is never offer glare.
/// * The callee answers each new offer rev with `answer: {sdp, type, rev}`.
/// * Each side trickles ICE candidates into its own subcollection
///   (`callerCandidates` / `calleeCandidates`).
/// * `status` drives the lifecycle; transitions out of `ringing` go through
///   transactions so "accept" and "cancel" can't both win.
class CallSession extends ChangeNotifier {
  CallSession({
    required this.call,
    required this.selfId,
    required void Function(CallSession session) onFinished,
  })  : _onFinished = onFinished,
        _doc = FirebaseFirestore.instance.collection('calls').doc(call.id),
        _phase = call.callerId == selfId ? CallPhase.outgoing : CallPhase.incoming,
        _speakerOn = call.isVideo,
        _docCreated = call.callerId != selfId;

  final CallModel call;
  final String selfId;
  final void Function(CallSession session) _onFinished;
  final DocumentReference<Map<String, dynamic>> _doc;

  bool get isCaller => call.callerId == selfId;
  bool get isVideo => call.isVideo;
  String get peerId => call.otherUserId(selfId);
  String get peerName => call.otherUserName(selfId);
  String? get peerPhotoUrl => call.otherUserPhotoUrl(selfId);

  CallPhase _phase;
  CallPhase get phase => _phase;

  String? _endMessage;
  String? get endMessage => _endMessage;

  DateTime? _connectedAt;
  DateTime? get connectedAt => _connectedAt;

  bool _micMuted = false;
  bool get micMuted => _micMuted;
  bool _cameraOff = false;
  bool get cameraOff => _cameraOff;
  bool _speakerOn;
  bool get speakerOn => _speakerOn;
  bool _frontCamera = true;
  bool get frontCamera => _frontCamera;

  bool _remoteMicMuted = false;
  bool get remoteMicMuted => _remoteMicMuted;
  bool _remoteCameraOff = false;
  bool get remoteCameraOff => _remoteCameraOff;

  MediaStream? _localStream;
  MediaStream? get localStream => _localStream;
  MediaStream? _remoteStream;
  MediaStream? get remoteStream => _remoteStream;

  RTCPeerConnection? _pc;
  StreamSubscription? _docSub;
  StreamSubscription? _candidateSub;
  Timer? _ringTimer;
  Timer? _connectTimer;
  Timer? _reconnectTimer;
  Timer? _iceRestartTimer;

  /// Caller: rev of the latest offer sent. Callee: unused.
  int _offerRev = 0;

  /// Caller: rev of the latest answer applied. Callee: rev of the latest
  /// offer answered.
  int _handledRev = -1;

  bool _docCreated;
  bool _remoteDescriptionSet = false;
  bool _sendersTuned = false;
  bool _finished = false;
  final List<RTCIceCandidate> _pendingLocalCandidates = [];
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  final List<DocumentReference> _sentCandidateRefs = [];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> startOutgoing() async {
    try {
      await _openMedia();
      if (_finished) return;
      // Start now, while the app is surely in the foreground: Android won't
      // start a microphone foreground service from the background.
      CallPlatform.onCallActive(video: isVideo, title: peerName);
      await _createPeerConnection();
      if (_finished) return;

      final offer = await _createLocalDescription(offer: true);
      await _doc.set({
        'callerId': call.callerId,
        'callerName': call.callerName,
        'callerPhotoUrl': call.callerPhotoUrl ?? '',
        'calleeId': call.calleeId,
        'calleeName': call.calleeName,
        'calleePhotoUrl': call.calleePhotoUrl ?? '',
        'participants': [call.callerId, call.calleeId],
        'type': call.type.name,
        'status': CallStatus.ringing.name,
        'offer': {'type': offer.type, 'sdp': offer.sdp, 'rev': _offerRev},
        'media': {selfId: _mediaState},
        'createdAt': FieldValue.serverTimestamp(),
      });
      _docCreated = true;

      if (_finished) {
        // Hung up while the document was being written.
        await _doc.update({
          'status': CallStatus.cancelled.name,
          'endedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      for (final candidate in _pendingLocalCandidates) {
        _sendLocalCandidate(candidate);
      }
      _pendingLocalCandidates.clear();

      _listenToCallDocument();
      _listenToRemoteCandidates();
      _ringTimer = Timer(CallConfig.ringTimeout, _onRingTimeout);
    } catch (e) {
      _fail(e);
    }
  }

  void startIncoming() {
    CallPlatform.startRinging();
    _listenToCallDocument();

    final age = call.createdAt == null
        ? Duration.zero
        : DateTime.now().difference(call.createdAt!);
    var remaining = CallConfig.ringTimeout - age;
    if (remaining < const Duration(seconds: 10)) {
      remaining = const Duration(seconds: 10);
    }
    _ringTimer = Timer(remaining, _onRingTimeout);
  }

  Future<void> accept() async {
    if (_phase != CallPhase.incoming || _finished) return;
    _ringTimer?.cancel();
    await CallPlatform.stopRinging();
    if (_finished) return;
    _setPhase(CallPhase.connecting);

    try {
      await _openMedia();
      if (_finished) return;
      await _createPeerConnection();
      if (_finished) return;

      final snapshot = await _doc.get();
      final offer = snapshot.data()?['offer'] as Map<String, dynamic>?;
      if (offer == null) throw StateError('Call has no offer');

      final rev = (offer['rev'] as num?)?.toInt() ?? 0;
      final answer = await _answerOffer(offer, rev);
      if (_finished) return;

      final accepted = await _updateStatus((current) {
        if (current != CallStatus.ringing) return null;
        return {
          'status': CallStatus.accepted.name,
          'answer': {'type': answer.type, 'sdp': answer.sdp, 'rev': rev},
          'answeredAt': FieldValue.serverTimestamp(),
          'media.$selfId': _mediaState,
        };
      });
      if (accepted != true) {
        _finishLocally('Call is no longer available');
        return;
      }
      // Hung up while the transaction was in flight.
      if (_finished) return;

      _listenToRemoteCandidates();
      _connectTimer = Timer(CallConfig.connectTimeout, _onConnectTimeout);
      CallPlatform.onCallActive(video: isVideo, title: peerName);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> decline() => _endCall(
        message: 'Call declined',
        whenRinging: CallStatus.declined,
      );

  /// The red button: cancel, decline or hang up depending on the phase.
  Future<void> hangUp() {
    switch (_phase) {
      case CallPhase.incoming:
        return decline();
      case CallPhase.outgoing:
        return _endCall(
          message: 'Call cancelled',
          whenRinging: CallStatus.cancelled,
        );
      default:
        return _endCall(message: 'Call ended');
    }
  }

  // ---------------------------------------------------------------------------
  // In-call controls
  // ---------------------------------------------------------------------------

  void toggleMic() {
    _micMuted = !_micMuted;
    for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !_micMuted;
    }
    notifyListeners();
    _publishMediaState();
  }

  void toggleCamera() {
    if (!isVideo) return;
    _cameraOff = !_cameraOff;
    for (final track in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !_cameraOff;
    }
    notifyListeners();
    _publishMediaState();
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    try {
      _frontCamera = await Helper.switchCamera(tracks.first);
      notifyListeners();
    } catch (e) {
      debugPrint('CallSession: switch camera failed: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    notifyListeners();
    await CallPlatform.setSpeakerphone(_speakerOn);
    _updateProximitySensor();
  }

  // ---------------------------------------------------------------------------
  // Media & peer connection
  // ---------------------------------------------------------------------------

  Map<String, bool> get _mediaState => {'mic': !_micMuted, 'cam': !_cameraOff};

  Future<void> _openMedia() async {
    await CallPlatform.prepareAudioSession(video: isVideo);
    try {
      _localStream = await navigator.mediaDevices
          .getUserMedia(CallConfig.mediaConstraints(video: isVideo));
    } catch (e) {
      debugPrint('CallSession: getUserMedia failed: $e');
      throw _CallFailure(isVideo
          ? 'Camera or microphone access was denied'
          : 'Microphone access was denied');
    }
    if (_finished) {
      await _stopStream(_localStream);
      _localStream = null;
      return;
    }
    notifyListeners();
    await CallPlatform.setSpeakerphone(_speakerOn);
    _updateProximitySensor();
  }

  Future<void> _createPeerConnection() async {
    final pc = await createPeerConnection(CallConfig.rtcConfiguration);
    final stream = _localStream;
    if (_finished || stream == null) {
      // Hung up while the connection was being created.
      await pc.close();
      await pc.dispose();
      return;
    }
    _pc = pc;

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) return;
      if (_docCreated) {
        _sendLocalCandidate(candidate);
      } else {
        _pendingLocalCandidates.add(candidate);
      }
    };

    pc.onTrack = (event) {
      if (event.streams.isEmpty || _finished) return;
      _remoteStream = event.streams.first;
      notifyListeners();
    };

    pc.onConnectionState = _onConnectionState;

    for (final track in stream.getTracks()) {
      await pc.addTrack(track, stream);
    }
  }

  /// Creates an offer/answer, applies HD audio tuning and sets it locally.
  Future<RTCSessionDescription> _createLocalDescription({
    required bool offer,
  }) async {
    final pc = _pc!;
    final description = offer ? await pc.createOffer() : await pc.createAnswer();
    final tuned = RTCSessionDescription(
      SdpUtils.enableHdAudio(
        description.sdp!,
        maxAverageBitrate: CallConfig.hdAudioBitrate,
      ),
      description.type,
    );
    await pc.setLocalDescription(tuned);
    return tuned;
  }

  /// Callee side: applies an offer (initial or ICE restart) and answers it.
  Future<RTCSessionDescription> _answerOffer(
    Map<String, dynamic> offer,
    int rev,
  ) async {
    // Claim the rev synchronously so concurrent snapshots don't re-apply it.
    _handledRev = rev;
    await _pc!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String?, offer['type'] as String?),
    );
    _remoteDescriptionSet = true;
    final answer = await _createLocalDescription(offer: false);
    await _flushRemoteCandidates();
    return answer;
  }

  /// Caller side: applies the answer that matches our latest offer.
  Future<void> _applyAnswer(Map<String, dynamic> answer) async {
    final rev = (answer['rev'] as num?)?.toInt() ?? 0;
    if (rev != _offerRev || rev <= _handledRev || _pc == null) return;
    _handledRev = rev;
    try {
      await _pc!.setRemoteDescription(
        RTCSessionDescription(
            answer['sdp'] as String?, answer['type'] as String?),
      );
      _remoteDescriptionSet = true;
      await _flushRemoteCandidates();
    } catch (e) {
      debugPrint('CallSession: applying answer rev $rev failed: $e');
    }
  }

  /// Callee side: the caller restarted ICE after a network change.
  Future<void> _answerRenegotiation(Map<String, dynamic> offer) async {
    final rev = (offer['rev'] as num?)?.toInt() ?? 0;
    if (rev <= _handledRev || _pc == null) return;
    try {
      final answer = await _answerOffer(offer, rev);
      if (_finished) return;
      await _doc.update({
        'answer': {'type': answer.type, 'sdp': answer.sdp, 'rev': rev},
      });
    } catch (e) {
      debugPrint('CallSession: answering offer rev $rev failed: $e');
    }
  }

  Future<void> _restartIce() async {
    _iceRestartTimer = null;
    final pc = _pc;
    if (pc == null || _finished || !isCaller) return;
    // Bump first so answers to the previous offer are ignored from now on.
    final rev = ++_offerRev;
    try {
      await pc.restartIce();
      final offer = await _createLocalDescription(offer: true);
      if (_finished) return;
      await _doc.update({
        'offer': {'type': offer.type, 'sdp': offer.sdp, 'rev': rev},
      });
    } catch (e) {
      debugPrint('CallSession: ICE restart failed: $e');
    }
  }

  void _onConnectionState(RTCPeerConnectionState state) {
    if (_finished) return;
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _connectTimer?.cancel();
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _iceRestartTimer?.cancel();
        _iceRestartTimer = null;
        _connectedAt ??= DateTime.now();
        _setPhase(CallPhase.connected);
        // iOS can reset the route when the audio session activates.
        CallPlatform.setSpeakerphone(_speakerOn);
        _tuneVideoSender();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _onConnectionLost();
        if (isCaller) {
          _iceRestartTimer ??= Timer(CallConfig.iceRestartDelay, _restartIce);
        }
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _onConnectionLost();
        if (isCaller) {
          _iceRestartTimer?.cancel();
          _restartIce();
        }
        break;
      default:
        break;
    }
  }

  void _onConnectionLost() {
    // Before the first connection the connect timeout is in charge.
    if (_connectedAt == null) return;
    _setPhase(CallPhase.reconnecting);
    _reconnectTimer ??= Timer(
      CallConfig.reconnectTimeout,
      () => _endCall(message: 'Connection lost'),
    );
  }

  /// Raises the video encoder's ceiling to HD; WebRTC's congestion control
  /// still lowers it automatically when bandwidth is short.
  Future<void> _tuneVideoSender() async {
    if (!isVideo || _sendersTuned || _pc == null) return;
    _sendersTuned = true;
    try {
      for (final sender in await _pc!.getSenders()) {
        if (sender.track?.kind != 'video') continue;
        final parameters = sender.parameters;
        final encodings = parameters.encodings;
        if (encodings == null || encodings.isEmpty) continue;
        for (final encoding in encodings) {
          encoding.maxBitrate = CallConfig.hdVideoMaxBitrate;
          encoding.maxFramerate = CallConfig.videoFrameRate;
        }
        parameters.degradationPreference = RTCDegradationPreference.BALANCED;
        await sender.setParameters(parameters);
      }
    } catch (e) {
      debugPrint('CallSession: tuning video sender failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Signaling
  // ---------------------------------------------------------------------------

  void _listenToCallDocument() {
    _docSub = _doc.snapshots().listen(
      _onCallDocument,
      onError: (e) => debugPrint('CallSession: call document error: $e'),
    );
  }

  void _onCallDocument(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (_finished) return;
    final data = snapshot.data();
    if (data == null) {
      _finishLocally('Call ended');
      return;
    }

    final peerMedia = (data['media'] as Map?)?[peerId] as Map?;
    if (peerMedia != null) {
      final micMuted = peerMedia['mic'] == false;
      final cameraOff = peerMedia['cam'] == false;
      if (micMuted != _remoteMicMuted || cameraOff != _remoteCameraOff) {
        _remoteMicMuted = micMuted;
        _remoteCameraOff = cameraOff;
        notifyListeners();
      }
    }

    final status = CallStatus.parse(data['status']);
    if (status.isTerminal) {
      _finishLocally(_messageForRemoteStatus(status));
      return;
    }

    if (isCaller) {
      if (status == CallStatus.accepted && _phase == CallPhase.outgoing) {
        _ringTimer?.cancel();
        _setPhase(CallPhase.connecting);
        _connectTimer = Timer(CallConfig.connectTimeout, _onConnectTimeout);
      }
      final answer = data['answer'] as Map<String, dynamic>?;
      if (answer != null) _applyAnswer(answer);
    } else if (_phase != CallPhase.incoming && _handledRev >= 0) {
      final offer = data['offer'] as Map<String, dynamic>?;
      if (offer != null) _answerRenegotiation(offer);
    }
  }

  void _listenToRemoteCandidates() {
    final collection = isCaller ? 'calleeCandidates' : 'callerCandidates';
    _candidateSub = _doc.collection(collection).snapshots().listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data();
          if (data == null) continue;
          _addRemoteCandidate(RTCIceCandidate(
            data['candidate'] as String?,
            data['sdpMid'] as String?,
            (data['sdpMLineIndex'] as num?)?.toInt(),
          ));
        }
      },
      onError: (e) => debugPrint('CallSession: candidate stream error: $e'),
    );
  }

  Future<void> _addRemoteCandidate(RTCIceCandidate candidate) async {
    if (_finished || _pc == null) return;
    if (!_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }
    try {
      await _pc!.addCandidate(candidate);
    } catch (_) {
      // Usually a candidate from a newer ICE generation arriving before its
      // description; retry after the next remote description is applied.
      _pendingRemoteCandidates.add(candidate);
    }
  }

  Future<void> _flushRemoteCandidates() async {
    final pending = List<RTCIceCandidate>.of(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in pending) {
      if (_pc == null) return;
      try {
        await _pc!.addCandidate(candidate);
      } catch (e) {
        debugPrint('CallSession: dropping stale ICE candidate: $e');
      }
    }
  }

  Future<void> _sendLocalCandidate(RTCIceCandidate candidate) async {
    final ref = _doc
        .collection(isCaller ? 'callerCandidates' : 'calleeCandidates')
        .doc();
    _sentCandidateRefs.add(ref);
    try {
      await ref.set({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    } catch (e) {
      debugPrint('CallSession: sending ICE candidate failed: $e');
    }
  }

  void _publishMediaState() {
    if (!_docCreated || _finished) return;
    _doc.update({'media.$selfId': _mediaState}).catchError(
      (Object e) => debugPrint('CallSession: publishing media state failed: $e'),
    );
  }

  /// Runs a status transition in a transaction. [build] gets the current
  /// status and returns the update to apply, or null to leave it untouched.
  ///
  /// Returns true if written, false if [build] declined, null on error.
  Future<bool?> _updateStatus(
    Map<String, dynamic>? Function(CallStatus current) build,
  ) async {
    try {
      return await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(_doc);
        if (!snapshot.exists) return false;
        final update = build(CallStatus.parse(snapshot.data()?['status']));
        if (update == null) return false;
        tx.update(_doc, update);
        return true;
      });
    } catch (e) {
      debugPrint('CallSession: status update failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Ending
  // ---------------------------------------------------------------------------

  Future<void> _onRingTimeout() async {
    if (_finished) return;
    final result = await _updateStatus((current) {
      if (current != CallStatus.ringing) return null;
      return {
        'status': CallStatus.missed.name,
        'endedAt': FieldValue.serverTimestamp(),
      };
    });
    // false means the call moved on (accepted/ended) and the document
    // listener is handling it; on error we still stop ringing locally.
    if (result != false) {
      _finishLocally(isCaller ? 'No answer' : 'Missed call');
    }
  }

  void _onConnectTimeout() {
    if (_connectedAt != null) return;
    _endCall(
      message: "Couldn't connect. Check your internet connection.",
      whenRinging: CallStatus.failed,
      whenAccepted: CallStatus.failed,
    );
  }

  void _fail(Object error) {
    debugPrint('CallSession: call failed: $error');
    _endCall(
      message: error is _CallFailure ? error.message : 'Call failed',
      whenRinging: CallStatus.failed,
      whenAccepted: CallStatus.failed,
    );
  }

  /// Ends the call locally right away (snappy UI), then records the outcome.
  Future<void> _endCall({
    required String message,
    CallStatus whenRinging = CallStatus.cancelled,
    CallStatus whenAccepted = CallStatus.ended,
  }) async {
    if (_finished) return;
    final duration = _connectedAt == null
        ? 0
        : DateTime.now().difference(_connectedAt!).inSeconds;
    _finishLocally(message);
    if (!_docCreated) return;

    await _updateStatus((current) {
      if (current.isTerminal) return null;
      return {
        'status': (current == CallStatus.ringing ? whenRinging : whenAccepted)
            .name,
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': selfId,
        'duration': duration,
      };
    });
  }

  void _finishLocally(String message) {
    if (_finished) return;
    _finished = true;
    _endMessage = message;
    _phase = CallPhase.ended;

    for (final timer in [_ringTimer, _connectTimer, _reconnectTimer, _iceRestartTimer]) {
      timer?.cancel();
    }
    _docSub?.cancel();
    _candidateSub?.cancel();

    final localStream = _localStream;
    final pc = _pc;
    _localStream = null;
    _remoteStream = null;
    _pc = null;

    notifyListeners();
    _onFinished(this);

    CallPlatform.onCallFinished();
    _releaseMedia(localStream, pc);
    _deleteSentCandidates();
  }

  Future<void> _releaseMedia(MediaStream? stream, RTCPeerConnection? pc) async {
    await _stopStream(stream);
    try {
      await pc?.close();
      await pc?.dispose();
    } catch (e) {
      debugPrint('CallSession: closing peer connection failed: $e');
    }
  }

  static Future<void> _stopStream(MediaStream? stream) async {
    if (stream == null) return;
    try {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    } catch (e) {
      debugPrint('CallSession: stopping local media failed: $e');
    }
  }

  /// Candidates are useless once the call is over; don't leave them behind.
  Future<void> _deleteSentCandidates() async {
    if (_sentCandidateRefs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final ref in _sentCandidateRefs) {
      batch.delete(ref);
    }
    _sentCandidateRefs.clear();
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('CallSession: cleaning up ICE candidates failed: $e');
    }
  }

  String _messageForRemoteStatus(CallStatus status) {
    switch (status) {
      case CallStatus.declined:
        return 'Call declined';
      case CallStatus.busy:
        return '$peerName is on another call';
      case CallStatus.missed:
        return isCaller ? 'No answer' : 'Missed call';
      case CallStatus.cancelled:
        return 'Missed call';
      case CallStatus.failed:
        return 'Call failed';
      default:
        return 'Call ended';
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _setPhase(CallPhase phase) {
    if (_phase == phase || _finished) return;
    _phase = phase;
    _updateProximitySensor();
    notifyListeners();
  }

  void _updateProximitySensor() {
    final active = _phase != CallPhase.incoming && _phase != CallPhase.ended;
    CallPlatform.setProximitySensor(active && !isVideo && !_speakerOn);
  }
}

class _CallFailure implements Exception {
  const _CallFailure(this.message);
  final String message;
}
