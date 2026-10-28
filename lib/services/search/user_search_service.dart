import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../user/user_profile.dart';
import '../user/user_repository.dart';

/// Finds people by name or @username with indexed prefix queries.
///
/// The old search downloaded the entire `users` collection on every
/// keystroke; this reads at most [_limit] documents per query, results are
/// remembered for the lifetime of the service, and callers debounce typing.
class UserSearchService {
  static const int _limit = 20;
  static const int minNameLength = 2;

  final CollectionReference<Map<String, dynamic>> _users =
      FirebaseFirestore.instance.collection('users');
  final Map<String, List<UserProfile>> _cache = {};

  /// Whether [query] is long enough to hit the network.
  static bool isSearchable(String query) {
    final q = query.trim();
    return q.startsWith('@') ? q.length >= 2 : q.length >= minNameLength;
  }

  Future<List<UserProfile>> search(String query, {required String selfId}) async {
    final q = query.trim().toLowerCase();
    if (!isSearchable(q)) return const [];
    final cached = _cache[q];
    if (cached != null) return cached;

    final futures =
        <Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[];
    if (q.startsWith('@')) {
      futures.add(_prefix('username', q));
    } else {
      futures
        ..add(_prefix('nameLower', q))
        // Accounts not yet indexed by nameLower, whose names usually start
        // with a capital letter.
        ..add(_prefix('name', q[0].toUpperCase() + q.substring(1)))
        // People often type a username without the "@".
        ..add(_prefix('username', '@$q'));
    }

    final byId = <String, UserProfile>{};
    for (final docs in await Future.wait(futures)) {
      for (final doc in docs) {
        if (doc.id == selfId) continue;
        byId[doc.id] = UserProfile.fromMap(doc.id, doc.data());
      }
    }

    final results = byId.values.toList()
      ..sort((a, b) => _rank(a, q).compareTo(_rank(b, q)));
    for (final profile in results) {
      UserRepository.instance.remember(profile);
    }
    return _cache[q] = results;
  }

  /// One failing query (e.g. offline with nothing cached) mustn't sink
  /// the others.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _prefix(
      String field, String prefix) async {
    try {
      final snapshot = await _users
          .where(field, isGreaterThanOrEqualTo: prefix)
          .where(field, isLessThan: '$prefix')
          .limit(_limit)
          .get();
      return snapshot.docs;
    } catch (e) {
      debugPrint('UserSearchService: $field search failed: $e');
      return const [];
    }
  }

  /// Exact matches first, then prefix matches, then alphabetical.
  static String _rank(UserProfile profile, String q) {
    final name = profile.name.toLowerCase();
    final username = profile.username.toLowerCase();
    final bare = q.startsWith('@') ? q.substring(1) : q;
    final exact = name == bare || username == '@$bare';
    final prefix = name.startsWith(bare) || username.startsWith('@$bare');
    return '${exact ? 0 : prefix ? 1 : 2}$name';
  }
}
