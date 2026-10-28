import 'dart:async';

import 'package:chatspot/services/friend/friend_repository.dart';
import 'package:chatspot/services/user/user_repository.dart';
import 'package:chatspot/views/call/call_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'call_config.dart';
import 'call_model.dart';
import 'call_notifications.dart';
import 'call_session.dart';

/// App-wide entry point for calls: places outgoing calls, listens for
/// incoming ones and makes sure only one call is active at a time.
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  /// Attached to [MaterialApp] so incoming calls can open from any screen.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final CollectionReference<Map<String, dynamic>> _calls =
      FirebaseFirestore.instance.collection('calls');

  String? _userId;
  StreamSubscription? _incomingSub;
  StreamSubscription? _nativeActionSub;
  final Set<String> _seenCallIds = {};
  bool _isStarting = false;

  /// Calls ringing on the native call screen because the app was in the
  /// background when they arrived.
  final Set<String> _nativeRingingIds = {};

  /// Calls that went through the native call screen and must be cleared
  /// from it when they end.
  final Set<String> _nativeCallIds = {};

  /// Accepted on the native screen before the user was signed in.
  String? _pendingAcceptId;
  String? _joiningCallId;

  CallSession? _activeSession;
  CallSession? get activeSession => _activeSession;

  /// Listens for taps on the native call screen. Call once at startup, before
  /// the user is known: an accept can be what launched the app.
  void init() {
    _nativeActionSub ??= CallNotifications.actions.listen((action) {
      final (type, callId) = action;
      switch (type) {
        case NativeCallAction.accept:
          _onNativeAccept(callId);
        case NativeCallAction.decline:
          _nativeRingingIds.remove(callId);
          _nativeCallIds.remove(callId);
          closeRingingCall(callId, CallStatus.declined);
      }
    });
  }

  /// Starts listening for incoming calls. Safe to call repeatedly.
  void attach(String userId) {
    if (_userId == userId) return;
    detach();
    _userId = userId;
    _startListening(userId);
  }

  Future<void> _startListening(String userId) async {
    // A call accepted on the native screen while the app was closed: join it
    // instead of ringing for it again.
    final acceptedId =
        _pendingAcceptId ?? await CallNotifications.acceptedCallId();
    _pendingAcceptId = null;
    if (_userId != userId) return;
    if (acceptedId != null) _seenCallIds.add(acceptedId);

    _incomingSub = _calls
        .where('calleeId', isEqualTo: userId)
        .where('status', isEqualTo: CallStatus.ringing.name)
        // Metadata changes let us see the cache -> server transition.
        .snapshots(includeMetadataChanges: true)
        .listen(
          _onIncomingCalls,
          onError: (e) => debugPrint('CallService: incoming calls error: $e'),
        );

    if (acceptedId != null) _joinAcceptedCall(acceptedId, userId);
  }

  /// Stops listening and ends any active call (e.g. on sign-out).
  void detach() {
    _incomingSub?.cancel();
    _incomingSub = null;
    _userId = null;
    _seenCallIds.clear();
    for (final callId in _nativeCallIds) {
      CallNotifications.end(callId);
    }
    _nativeCallIds.clear();
    _nativeRingingIds.clear();
    _activeSession?.hangUp();
  }

  Future<void> startCall(
    BuildContext context, {
    required String calleeId,
    required String calleeName,
    String? calleePhotoUrl,
    required CallType type,
  }) async {
    final userId = _userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _isStarting) return;

    final messenger = ScaffoldMessenger.of(context);
    if (_activeSession != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('You are already in a call')),
      );
      return;
    }

    _isStarting = true;
    try {
      // Both answered from memory; no reads.
      final areFriends =
          await FriendRepository.instance.isFriendConfirmed(calleeId);
      final me = UserRepository.instance.me.value ??
          await UserRepository.instance.get(userId);

      if (!areFriends) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('You can only call friends'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_activeSession != null) return;

      final call = CallModel(
        id: _calls.doc().id,
        callerId: userId,
        callerName: me?.displayName ?? 'Unknown',
        callerPhotoUrl:
            (me?.photoUrl.isNotEmpty ?? false) ? me!.photoUrl : null,
        calleeId: calleeId,
        calleeName: calleeName,
        calleePhotoUrl:
            (calleePhotoUrl?.isNotEmpty ?? false) ? calleePhotoUrl : null,
        type: type,
        status: CallStatus.ringing,
      );
      final session = _present(call, userId);
      session?.startOutgoing();
    } catch (e) {
      debugPrint('CallService: starting call failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start the call')),
      );
    } finally {
      _isStarting = false;
    }
  }

  void _onIncomingCalls(QuerySnapshot<Map<String, dynamic>> snapshot) {
    // Never ring for data the server hasn't confirmed — a cached "ringing"
    // document may have been answered or cancelled long ago.
    if (snapshot.metadata.isFromCache) return;
    final userId = _userId;
    if (userId == null) return;

    // A natively ringing call that left the query was cancelled or timed out.
    final ringingIds = snapshot.docs.map((doc) => doc.id).toSet();
    for (final callId in _nativeRingingIds.difference(ringingIds).toList()) {
      _nativeRingingIds.remove(callId);
      _nativeCallIds.remove(callId);
      CallNotifications.end(callId);
    }

    for (final doc in snapshot.docs) {
      if (!_seenCallIds.add(doc.id)) continue;
      final call = CallModel.fromDoc(doc);

      final createdAt = call.createdAt;
      final isStale = createdAt != null &&
          DateTime.now().difference(createdAt) >
              CallConfig.ringTimeout + const Duration(seconds: 15);
      if (isStale) {
        closeRingingCall(call.id, CallStatus.missed);
        continue;
      }
      if (_activeSession != null ||
          _isStarting ||
          _joiningCallId != null ||
          _nativeRingingIds.isNotEmpty) {
        closeRingingCall(call.id, CallStatus.busy);
        continue;
      }

      if (_isAppVisible || !CallNotifications.isSupported) {
        _present(call, userId)?.startIncoming();
      } else {
        // Android won't let a backgrounded app open its own screen; the
        // system call screen can ring over anything, including the lock
        // screen.
        _nativeRingingIds.add(call.id);
        _nativeCallIds.add(call.id);
        CallNotifications.showIncoming(
          callId: call.id,
          callerName: call.callerName,
          callerPhotoUrl: call.callerPhotoUrl,
          video: call.isVideo,
          createdAt: call.createdAt,
        );
      }
    }
  }

  static bool get _isAppVisible {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  void _onNativeAccept(String callId) {
    _nativeRingingIds.remove(callId);
    _nativeCallIds.add(callId);
    final userId = _userId;
    if (userId == null || _incomingSub == null) {
      // Still starting up; [_startListening] picks it up.
      _pendingAcceptId = callId;
      return;
    }
    _seenCallIds.add(callId);
    _joinAcceptedCall(callId, userId);
  }

  /// Opens the call screen for a call accepted on the native screen and
  /// connects it without ringing again.
  Future<void> _joinAcceptedCall(String callId, String userId) async {
    if (_activeSession?.call.id == callId || _joiningCallId == callId) return;
    _joiningCallId = callId;
    try {
      final doc = await _calls.doc(callId).get();
      final call = doc.exists ? CallModel.fromDoc(doc) : null;
      if (call == null ||
          call.calleeId != userId ||
          call.status != CallStatus.ringing ||
          _activeSession != null) {
        // The caller gave up before the app finished opening.
        _nativeCallIds.remove(callId);
        CallNotifications.end(callId);
        _showMessage('The call has ended');
        return;
      }
      _present(call, userId)?.startAccepted();
    } catch (e) {
      debugPrint('CallService: joining call $callId failed: $e');
      _nativeCallIds.remove(callId);
      CallNotifications.end(callId);
    } finally {
      _joiningCallId = null;
    }
  }

  void _showMessage(String text) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  CallSession? _present(CallModel call, String userId) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('CallService: no navigator to show call ${call.id}');
      return null;
    }

    final session = CallSession(
      call: call,
      selfId: userId,
      onFinished: (session) {
        if (identical(_activeSession, session)) _activeSession = null;
        if (_nativeCallIds.remove(session.call.id)) {
          CallNotifications.end(session.call.id);
        }
      },
    );
    _activeSession = session;
    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(session: session),
      ),
    );
    return session;
  }

  /// Ends a call that is still ringing, e.g. declined from the native call
  /// screen. Static so the push background isolate can use it.
  static Future<void> closeRingingCall(String callId, CallStatus status) async {
    final ref = FirebaseFirestore.instance.collection('calls').doc(callId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(ref);
        if (snapshot.data()?['status'] != CallStatus.ringing.name) return;
        tx.update(ref, {
          'status': status.name,
          'endedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('CallService: marking call $callId as ${status.name} failed: $e');
    }
  }

  /// Recent calls involving [userId], newest first.
  ///
  /// Uses a composite index (participants + createdAt, see
  /// firestore.indexes.json). Until it is deployed, falls back to an
  /// unordered query sorted on the client.
  Stream<List<CallModel>> callHistory(String userId, {int limit = 50}) async* {
    final byUser = _calls.where('participants', arrayContains: userId);
    try {
      await for (final snapshot in byUser
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()) {
        yield snapshot.docs.map(CallModel.fromDoc).toList();
      }
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      debugPrint('CallService: call history index missing, '
          'falling back to client-side sorting. ${e.message}');
      await for (final snapshot in byUser.snapshots()) {
        final calls = snapshot.docs.map(CallModel.fromDoc).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime.now())
              .compareTo(a.createdAt ?? DateTime.now()));
        yield calls.take(limit).toList();
      }
    }
  }
}
