import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../user/user_profile.dart';

/// Recently opened profiles, kept on this device only.
///
/// History used to live on the user document, costing a read plus one read
/// per entry every time search opened, and a write per visit.
class SearchHistoryStore {
  SearchHistoryStore(this.uid);

  static const int _maxEntries = 15;

  final String uid;

  String get _key => 'search_history_v1_$uid';

  Future<List<UserProfile>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const [];
      return [
        for (final entry in jsonDecode(raw) as List)
          UserProfile.fromJson(entry as Map<String, dynamic>),
      ];
    } catch (e) {
      debugPrint('SearchHistoryStore: reading history failed: $e');
      return const [];
    }
  }

  Future<List<UserProfile>> add(UserProfile profile) async {
    final history = (await load()).where((p) => p.uid != profile.uid).toList()
      ..insert(0, _public(profile));
    return _save(history.take(_maxEntries).toList());
  }

  Future<List<UserProfile>> remove(String userId) async =>
      _save((await load()).where((p) => p.uid != userId).toList());

  Future<List<UserProfile>> clear() => _save(const []);

  Future<List<UserProfile>> _save(List<UserProfile> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode([for (final p in history) p.toJson()]));
    } catch (e) {
      debugPrint('SearchHistoryStore: writing history failed: $e');
    }
    return history;
  }

  /// Other people's email and birthday don't belong on disk.
  static UserProfile _public(UserProfile p) => UserProfile(
      uid: p.uid, name: p.name, username: p.username, photoUrl: p.photoUrl);
}
