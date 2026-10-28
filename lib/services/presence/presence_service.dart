import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import '../friend/friend_models.dart';
import '../friend/friend_repository.dart';

/// Whether someone has the app open, and when they last did.
class Presence {
  const Presence({required this.online, required this.lastActive});

  static const Presence unknown = Presence(online: false, lastActive: null);

  final bool online;
  final DateTime? lastActive;

  /// "Online" from an app that was killed without saying goodbye goes stale
  /// once its heartbeat stops.
  bool isActiveNow(DateTime now) =>
      online &&
      lastActive != null &&
      now.difference(lastActive!) < PresenceService.staleAfter;

  /// Minutes since they left, for the small badge on avatars; null when
  /// active now, unknown, or longer ago than an hour.
  int? minutesAway(DateTime now) {
    if (isActiveNow(now) || lastActive == null) return null;
    final minutes = now.difference(lastActive!).inMinutes;
    return minutes < 60 ? (minutes < 1 ? 1 : minutes) : null;
  }

  /// "Active now", "Active 5m ago", "Active 3h ago", "Active 2d ago", or
  /// null when unknown or more than a week ago.
  String? label(DateTime now) {
    if (isActiveNow(now)) return 'Active now';
    final last = lastActive;
    if (last == null) return null;
    final away = now.difference(last);
    if (away.inMinutes < 1) return 'Active just now';
    if (away.inMinutes < 60) return 'Active ${away.inMinutes}m ago';
    if (away.inHours < 24) return 'Active ${away.inHours}h ago';
    if (away.inDays < 7) return 'Active ${away.inDays}d ago';
    return null;
  }
}

/// Publishes the signed-in user's presence and follows their friends'.
///
/// Cost-conscious by design:
/// * Own status is written when the app comes to the foreground or leaves
///   it, plus a heartbeat every [heartbeat] while open (so a crashed app
///   stops showing "Active now"). One tiny document, `presence/{uid}`.
/// * Friends' presence is followed only while the app is in the foreground,
///   in batches of 30 per listener.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  static const Duration heartbeat = Duration(minutes: 10);
  static const Duration staleAfter = Duration(minutes: 12);

  /// Firestore allows 30 values in a `whereIn` filter.
  static const int _batchSize = 30;

  final CollectionReference<Map<String, dynamic>> _presence =
      FirebaseFirestore.instance.collection('presence');

  /// Friends' presence by uid.
  final ValueNotifier<Map<String, Presence>> presence = ValueNotifier({});

  /// Ticks every minute so "5m ago" labels stay current without rebuilding
  /// on every presence change.
  final ValueNotifier<DateTime> clock = ValueNotifier(DateTime.now());

  String? _uid;
  bool _foreground = true;
  Timer? _heartbeatTimer;
  Timer? _clockTimer;
  final List<StreamSubscription> _subs = [];
  List<String> _watched = const [];

  Presence of(String uid) => presence.value[uid] ?? Presence.unknown;

  void start(String uid) {
    _uid = uid;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    FriendRepository.instance.state.addListener(_onFriendsChanged);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      clock.value = DateTime.now();
    });
    if (_foreground) _publish(online: true);
    _onFriendsChanged();
  }

  /// Marks the user offline while still signed in (rules require it).
  Future<void> goOffline() async {
    if (_uid == null) return;
    try {
      await _publish(online: false).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Offline: it goes stale by itself.
    }
  }

  Future<void> stop() async {
    WidgetsBinding.instance.removeObserver(this);
    FriendRepository.instance.state.removeListener(_onFriendsChanged);
    _uid = null;
    _heartbeatTimer?.cancel();
    _clockTimer?.cancel();
    await _unlisten();
    _watched = const [];
    presence.value = {};
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_foreground) return;
        _foreground = true;
        clock.value = DateTime.now();
        _publish(online: true);
        _listen();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!_foreground) return;
        _foreground = false;
        _publish(online: false);
        // Nobody sees the list while the app is in the background.
        _unlisten();
      case AppLifecycleState.inactive:
        // Transient (notification shade, system dialogs): ignore.
        break;
    }
  }

  Future<void> _publish({required bool online}) {
    final uid = _uid;
    _heartbeatTimer?.cancel();
    if (uid == null) return Future.value();
    if (online) {
      _heartbeatTimer =
          Timer.periodic(heartbeat, (_) => _publish(online: true));
    }
    return _presence.doc(uid).set({
      'online': online,
      'lastActive': FieldValue.serverTimestamp(),
    }).catchError((Object e) {
      debugPrint('PresenceService: publishing presence failed: $e');
    });
  }

  void _onFriendsChanged() {
    final FriendsState state = FriendRepository.instance.state.value;
    final ids = state.friends.map((f) => f.uid).toList()..sort();
    if (_sameIds(ids, _watched)) return;
    _watched = ids;
    presence.value = {
      for (final entry in presence.value.entries)
        if (ids.contains(entry.key)) entry.key: entry.value,
    };
    if (_foreground) _listen();
  }

  Future<void> _listen() async {
    await _unlisten();
    if (_uid == null) return;
    for (var i = 0; i < _watched.length; i += _batchSize) {
      final batch = _watched.skip(i).take(_batchSize).toList();
      _subs.add(_presence
          .where(FieldPath.documentId, whereIn: batch)
          .snapshots()
          .listen((snapshot) {
        final next = Map<String, Presence>.of(presence.value);
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final lastActive = data['lastActive'];
          next[doc.id] = Presence(
            online: data['online'] == true,
            lastActive: lastActive is Timestamp ? lastActive.toDate() : null,
          );
        }
        presence.value = next;
      }, onError: (Object e) {
        debugPrint('PresenceService: presence stream error: $e');
      }));
    }
  }

  Future<void> _unlisten() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
