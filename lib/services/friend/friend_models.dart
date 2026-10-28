import 'package:cloud_firestore/cloud_firestore.dart';

import '../user/user_profile.dart';

/// How the signed-in user relates to someone else.
enum Relationship { self, friend, requestSent, requestReceived, none }

class Friend {
  const Friend({
    required this.friendshipId,
    required this.uid,
    required this.name,
    required this.username,
    required this.photoUrl,
  });

  final String friendshipId;
  final String uid;
  final String name;
  final String username;
  final String photoUrl;

  String get displayName => name.isNotEmpty ? name : 'Unknown';

  UserProfile toProfile() =>
      UserProfile(uid: uid, name: name, username: username, photoUrl: photoUrl);

  /// `friendships/{id}`: `users: [a, b]`, `userDetails: {uid: {...}}`.
  static Friend? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc,
      String selfId) {
    final data = doc.data();
    if (data == null) return null;
    final users = List<String>.from(data['users'] as List? ?? const []);
    final uid = users.firstWhere((id) => id != selfId, orElse: () => '');
    if (uid.isEmpty) return null;
    final details =
        (data['userDetails'] as Map?)?[uid] as Map? ?? const {};
    return Friend(
      friendshipId: doc.id,
      uid: uid,
      name: details['name'] as String? ?? '',
      username: details['username'] as String? ?? '',
      photoUrl: details['profilePic'] as String? ?? '',
    );
  }
}

/// A pending request in `friend_requests/{id}`.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.sender,
    required this.receiver,
    required this.sentAt,
    required this.seen,
  });

  final String id;
  final String senderId;
  final String receiverId;

  /// Snapshot of the sender's public profile at the time of sending.
  final UserProfile sender;

  /// Same for the receiver; empty on requests sent by older app versions.
  final UserProfile receiver;
  final DateTime? sentAt;
  final bool seen;

  static FriendRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final senderId = data['senderId'] as String? ?? '';
    final receiverId = data['receiverId'] as String? ?? '';
    final sentAt = data['timestamp'];
    return FriendRequest(
      id: doc.id,
      senderId: senderId,
      receiverId: receiverId,
      sender: UserProfile(
        uid: senderId,
        name: data['senderName'] as String? ?? '',
        username: data['senderUsername'] as String? ?? '',
        photoUrl: data['senderProfilePic'] as String? ?? '',
      ),
      receiver: UserProfile(
        uid: receiverId,
        name: data['receiverName'] as String? ?? '',
        username: data['receiverUsername'] as String? ?? '',
        photoUrl: data['receiverProfilePic'] as String? ?? '',
      ),
      // A request we just sent has no server time yet.
      sentAt: sentAt is Timestamp
          ? sentAt.toDate()
          : (doc.metadata.hasPendingWrites ? DateTime.now() : null),
      seen: data['seen'] == true,
    );
  }
}

class FriendsState {
  const FriendsState({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.loaded = false,
  });

  static const FriendsState empty = FriendsState();

  /// Sorted by name.
  final List<Friend> friends;

  /// Requests others sent us, newest first.
  final List<FriendRequest> incoming;

  /// Requests we sent, newest first.
  final List<FriendRequest> outgoing;

  /// The friends list has arrived (from the device cache or the server).
  final bool loaded;

  int get unseenCount => incoming.where((r) => !r.seen).length;

  Friend? friend(String uid) {
    for (final friend in friends) {
      if (friend.uid == uid) return friend;
    }
    return null;
  }

  FriendRequest? incomingFrom(String uid) {
    for (final request in incoming) {
      if (request.senderId == uid) return request;
    }
    return null;
  }

  FriendRequest? outgoingTo(String uid) {
    for (final request in outgoing) {
      if (request.receiverId == uid) return request;
    }
    return null;
  }
}
