import 'dart:async';

import 'package:chatspot/services/cache/user_cache_service.dart';
import 'package:chatspot/services/friend/friend_request_service.dart';
import 'package:chatspot/views/call/call_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'call_config.dart';
import 'call_model.dart';
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
  final Set<String> _seenCallIds = {};
  bool _isStarting = false;

  CallSession? _activeSession;
  CallSession? get activeSession => _activeSession;

  /// Starts listening for incoming calls. Safe to call repeatedly.
  void attach(String userId) {
    if (_userId == userId) return;
    detach();
    _userId = userId;
    _incomingSub = _calls
        .where('calleeId', isEqualTo: userId)
        .where('status', isEqualTo: CallStatus.ringing.name)
        // Metadata changes let us see the cache -> server transition.
        .snapshots(includeMetadataChanges: true)
        .listen(
          _onIncomingCalls,
          onError: (e) => debugPrint('CallService: incoming calls error: $e'),
        );
  }

  /// Stops listening and ends any active call (e.g. on sign-out).
  void detach() {
    _incomingSub?.cancel();
    _incomingSub = null;
    _userId = null;
    _seenCallIds.clear();
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
      final results = await Future.wait([
        FriendRequestService.areFriends(userId, calleeId),
        UserCacheService().getUserData(userId),
      ]);
      final areFriends = results[0] as bool;
      final me = results[1] as Map<String, dynamic>;

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
        callerName: me['name'] ?? 'Unknown',
        callerPhotoUrl: me['profilePictureUrl'],
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

    for (final doc in snapshot.docs) {
      if (!_seenCallIds.add(doc.id)) continue;
      final call = CallModel.fromDoc(doc);

      final createdAt = call.createdAt;
      final isStale = createdAt != null &&
          DateTime.now().difference(createdAt) >
              CallConfig.ringTimeout + const Duration(seconds: 15);
      if (isStale) {
        _closeRingingCall(call.id, CallStatus.missed);
        continue;
      }
      if (_activeSession != null || _isStarting) {
        _closeRingingCall(call.id, CallStatus.busy);
        continue;
      }

      _present(call, userId)?.startIncoming();
    }
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

  Future<void> _closeRingingCall(String callId, CallStatus status) async {
    final ref = _calls.doc(callId);
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
