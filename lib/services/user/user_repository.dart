import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile.dart';

/// Single source of user profiles for the whole app.
///
/// * The signed-in user's own profile is kept live by one document listener
///   ([me]); screens never read it again.
/// * Other profiles are cached in memory and on disk, and refetched at most
///   every [maxAge]. Concurrent requests for the same user share one read.
/// * Lists that already carry names and photos (friends, chats, search
///   results) [seed] the cache, so opening a profile usually costs nothing.
class UserRepository {
  UserRepository._();
  static final UserRepository instance = UserRepository._();

  static const String _prefsKey = 'user_profiles_v1';
  static const int _maxEntries = 300;
  static const Duration maxAge = Duration(hours: 12);

  final CollectionReference<Map<String, dynamic>> _users =
      FirebaseFirestore.instance.collection('users');

  final Map<String, _CachedProfile> _profiles = {};
  final Map<String, Future<UserProfile?>> _inFlight = {};
  Future<void>? _diskLoad;
  Timer? _persistTimer;

  /// The signed-in user's profile; null while signed out or loading.
  final ValueNotifier<UserProfile?> me = ValueNotifier(null);
  StreamSubscription? _meSub;
  String? _uid;

  Future<void> start(String uid) async {
    _uid = uid;
    await (_diskLoad ??= _loadFromDisk());
    if (_uid != uid) return;
    me.value = peek(uid);
    _meSub = _users.doc(uid).snapshots().listen(
      (snapshot) {
        final data = snapshot.data();
        if (data == null) return;
        final profile = UserProfile.fromMap(uid, data);
        _store(profile, complete: true);
        me.value = profile;
      },
      onError: (e) => debugPrint('UserRepository: own profile error: $e'),
    );
  }

  /// Signing out also forgets cached profiles: the next account on this
  /// device shouldn't inherit them.
  Future<void> stop() async {
    _uid = null;
    await _meSub?.cancel();
    _meSub = null;
    me.value = null;
    _profiles.clear();
    _inFlight.clear();
    _persistTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint('UserRepository: clearing cache failed: $e');
    }
  }

  /// Whatever is cached, without touching the network.
  UserProfile? peek(String uid) => _profiles[uid]?.profile;

  /// The full profile, from cache when fresh enough, otherwise one read.
  /// Offline, falls back to whatever is cached.
  Future<UserProfile?> get(String uid) async {
    await (_diskLoad ??= _loadFromDisk());
    final cached = _profiles[uid];
    if (cached != null && cached.complete && cached.age < maxAge) {
      return cached.profile;
    }
    return _inFlight[uid] ??= _fetch(uid).whenComplete(() {
      _inFlight.remove(uid);
    });
  }

  /// A complete profile that arrived as part of a query (e.g. search).
  void remember(UserProfile profile) => _store(profile, complete: true);

  /// Public fields that arrived for free (friends list, chat list).
  void seed(UserProfile profile) {
    final cached = _profiles[profile.uid];
    if (cached == null) {
      _store(profile, complete: false);
    } else {
      final merged = cached.profile.withPublicFieldsOf(profile);
      _profiles[profile.uid] =
          _CachedProfile(merged, cached.fetchedAt, cached.complete);
    }
  }

  Future<UserProfile?> _fetch(String uid) async {
    try {
      final snapshot = await _users.doc(uid).get();
      final data = snapshot.data();
      if (data == null) return null;
      final profile = UserProfile.fromMap(uid, data);
      _store(profile, complete: true);
      return profile;
    } catch (e) {
      debugPrint('UserRepository: fetching $uid failed: $e');
      return _profiles[uid]?.profile;
    }
  }

  void _store(UserProfile profile, {required bool complete}) {
    _profiles[profile.uid] =
        _CachedProfile(profile, DateTime.now(), complete);
    _persistSoon();
  }

  void _persistSoon() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 2), _saveToDisk);
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      for (final entry in jsonDecode(raw) as List) {
        final cached = _CachedProfile.fromJson(entry as Map<String, dynamic>);
        _profiles.putIfAbsent(cached.profile.uid, () => cached);
      }
    } catch (e) {
      debugPrint('UserRepository: reading cache failed: $e');
    }
  }

  Future<void> _saveToDisk() async {
    if (_uid == null) return;
    try {
      final entries = _profiles.values.toList()
        ..sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode([for (final e in entries.take(_maxEntries)) e.toJson()]),
      );
    } catch (e) {
      debugPrint('UserRepository: writing cache failed: $e');
    }
  }
}

class _CachedProfile {
  const _CachedProfile(this.profile, this.fetchedAt, this.complete);

  factory _CachedProfile.fromJson(Map<String, dynamic> json) => _CachedProfile(
        UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
        DateTime.fromMillisecondsSinceEpoch(json['fetchedAt'] as int),
        json['complete'] == true,
      );

  final UserProfile profile;
  final DateTime fetchedAt;

  /// False when only the public fields are known (seeded from a list).
  final bool complete;

  Duration get age => DateTime.now().difference(fetchedAt);

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'fetchedAt': fetchedAt.millisecondsSinceEpoch,
        'complete': complete,
      };
}
