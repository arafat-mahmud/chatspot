import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_messenger.dart';
import '../chat/chat_repository.dart';
import '../friend/friend_repository.dart';
import 'user_profile.dart';

/// Changes to the signed-in user's own profile.
///
/// Friend lists and chats keep a copy of each person's name and photo, so
/// they render without reading anyone's profile. Profile edits are rare, so
/// a change is copied into those documents once (fan-out) instead of every
/// device re-reading profiles all the time.
class ProfileService {
  ProfileService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Firestore allows 500 writes per batch.
  static const int _batchLimit = 450;

  static Future<void> update({
    String? name,
    String? username,
    String? photoUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final profile = <String, dynamic>{
      if (name != null) 'name': name,
      if (name != null) 'nameLower': name.toLowerCase(),
      if (username != null) 'username': username,
      if (photoUrl != null) 'profilePictureUrl': photoUrl,
    };
    if (profile.isEmpty) return;

    final friendFields = <String, dynamic>{
      if (name != null) 'userDetails.$uid.name': name,
      if (username != null) 'userDetails.$uid.username': username,
      if (photoUrl != null) 'userDetails.$uid.profilePic': photoUrl,
    };
    final chatFields = <String, dynamic>{
      if (name != null) 'users.$uid.name': name,
      if (username != null) 'users.$uid.username': username,
      if (photoUrl != null) 'users.$uid.photoUrl': photoUrl,
    };
    final requestFields = <String, dynamic>{
      if (name != null) 'senderName': name,
      if (username != null) 'senderUsername': username,
      if (photoUrl != null) 'senderProfilePic': photoUrl,
    };

    final writes = <void Function(WriteBatch)>[
      (b) => b.set(_db.collection('users').doc(uid), profile,
          SetOptions(merge: true)),
      for (final friend in FriendRepository.instance.state.value.friends)
        (b) => b.update(
            _db.collection('friendships').doc(friend.friendshipId),
            friendFields),
      for (final chat in ChatRepository.instance.allChats)
        (b) => b.update(_db.collection('chats').doc(chat.chatId), chatFields),
      for (final request in FriendRepository.instance.state.value.outgoing)
        (b) => b.update(
            _db.collection('friend_requests').doc(request.id), requestFields),
    ];

    for (var i = 0; i < writes.length; i += _batchLimit) {
      final batch = _db.batch();
      for (final write in writes.skip(i).take(_batchLimit)) {
        write(batch);
      }
      // Applied locally at once; synced when the network allows.
      batch.commit().catchError((Object e) {
        debugPrint('ProfileService: saving profile failed: $e');
        AppMessenger.error("Couldn't save your profile");
      });
    }
  }

  /// Accounts created before name search existed lack `nameLower`. Their
  /// owner's app adds it once; afterwards this never writes.
  static void ensureSearchable(UserProfile me) {
    final expected = me.name.toLowerCase();
    if (me.name.isEmpty || me.nameLower == expected) return;
    _db.collection('users').doc(me.uid).set(
      {'nameLower': expected},
      SetOptions(merge: true),
    ).catchError((Object e) {
      debugPrint('ProfileService: indexing name failed: $e');
    });
  }

  /// One read, only when the user has stopped typing (see callers).
  static Future<bool> isUsernameTaken(String username) async {
    final result = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return result.docs.any((doc) => doc.id != uid);
  }
}
