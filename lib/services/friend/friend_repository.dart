import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../app_messenger.dart';
import '../user/user_profile.dart';
import '../user/user_repository.dart';
import 'friend_models.dart';

enum RequestOutcome { sent, accepted, alreadyFriends, alreadySent, failed }

/// Friends and friend requests for the signed-in user.
///
/// Three listeners for the whole session (friends, received requests, sent
/// requests) replace every per-screen query: "are we friends?", "is there a
/// pending request?" and the badge counts are answered from memory, for
/// free. Firestore's on-device cache makes the first emission instant on
/// later app starts.
///
/// Writes are optimistic: Firestore applies them locally at once (the
/// listeners update the UI immediately, even offline) and failures are
/// reported through [AppMessenger].
class FriendRepository {
  FriendRepository._();
  static final FriendRepository instance = FriendRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('friend_requests');
  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection('friendships');

  final ValueNotifier<FriendsState> state = ValueNotifier(FriendsState.empty);

  String? _uid;
  final List<StreamSubscription> _subs = [];
  List<Friend> _friends = const [];
  List<FriendRequest> _incoming = const [];
  List<FriendRequest> _outgoing = const [];
  bool _friendsLoaded = false;
  Completer<void> _ready = Completer<void>();

  /// Friendship doc id for new friendships; older ones have random ids.
  static String friendshipIdFor(String a, String b) =>
      (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';

  void start(String uid) {
    _uid = uid;
    _subs.add(_friendships
        .where('users', arrayContains: uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen((snapshot) {
      final friends = snapshot.docs
          .map((doc) => Friend.fromDoc(doc, uid))
          .whereType<Friend>()
          .toList()
        ..sort((a, b) => a.displayName
          .toLowerCase()
          .compareTo(b.displayName.toLowerCase()));
      for (final friend in friends) {
        UserRepository.instance.seed(friend.toProfile());
      }
      _friends = friends;
      _friendsLoaded = true;
      if (!_ready.isCompleted) _ready.complete();
      _publish();
    }, onError: (e) => _onError('friends', e)));

    _subs.add(_pendingRequests('receiverId', uid).listen((requests) {
      _incoming = requests;
      _publish();
    }, onError: (e) => _onError('received requests', e)));

    _subs.add(_pendingRequests('senderId', uid).listen((requests) {
      _outgoing = requests;
      _publish();
    }, onError: (e) => _onError('sent requests', e)));
  }

  Future<void> stop() async {
    _uid = null;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _friends = const [];
    _incoming = const [];
    _outgoing = const [];
    _friendsLoaded = false;
    if (!_ready.isCompleted) _ready.complete();
    _ready = Completer<void>();
    state.value = FriendsState.empty;
  }

  Stream<List<FriendRequest>> _pendingRequests(String field, String uid) =>
      _requests
          .where(field, isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) => snapshot.docs.map(FriendRequest.fromDoc).toList()
            ..sort((a, b) => (b.sentAt ?? DateTime(0))
                .compareTo(a.sentAt ?? DateTime(0))));

  void _publish() {
    state.value = FriendsState(
      friends: _friends,
      incoming: _incoming,
      outgoing: _outgoing,
      loaded: _friendsLoaded,
    );
  }

  void _onError(String what, Object error) {
    debugPrint('FriendRepository: $what stream error: $error');
    // Don't leave screens on a loading state, or callers of
    // [isFriendConfirmed] waiting, forever.
    if (what == 'friends' && !_friendsLoaded) {
      _friendsLoaded = true;
      _publish();
    }
    if (!_ready.isCompleted) _ready.complete();
  }

  // ---------------------------------------------------------------------------
  // Queries (memory only)
  // ---------------------------------------------------------------------------

  bool isFriend(String uid) => state.value.friend(uid) != null;

  /// Like [isFriend], but waits for the friends list right after sign-in.
  Future<bool> isFriendConfirmed(String uid) async {
    if (!_friendsLoaded) {
      await _ready.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    }
    return isFriend(uid);
  }

  Relationship relationTo(String uid) {
    if (uid == _uid) return Relationship.self;
    final current = state.value;
    if (current.friend(uid) != null) return Relationship.friend;
    if (current.incomingFrom(uid) != null) return Relationship.requestReceived;
    if (current.outgoingTo(uid) != null) return Relationship.requestSent;
    return Relationship.none;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  RequestOutcome sendRequest(UserProfile target) {
    final uid = _uid;
    final me = UserRepository.instance.me.value;
    if (uid == null || me == null || target.uid == uid) {
      return RequestOutcome.failed;
    }
    switch (relationTo(target.uid)) {
      case Relationship.friend:
        return RequestOutcome.alreadyFriends;
      case Relationship.requestSent:
        return RequestOutcome.alreadySent;
      case Relationship.requestReceived:
        // They asked first: that's a yes on both sides.
        accept(state.value.incomingFrom(target.uid)!);
        return RequestOutcome.accepted;
      case Relationship.self:
      case Relationship.none:
        break;
    }

    // One request per direction; re-sending after a decline reuses it.
    _commit(
      _requests.doc('${uid}_${target.uid}').set({
        'senderId': uid,
        'receiverId': target.uid,
        'senderName': me.name,
        'senderUsername': me.username,
        'senderProfilePic': me.photoUrl,
        'receiverName': target.name,
        'receiverUsername': target.username,
        'receiverProfilePic': target.photoUrl,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
      }),
      "Couldn't send the friend request",
    );
    return RequestOutcome.sent;
  }

  void accept(FriendRequest request) {
    final uid = _uid;
    final me = UserRepository.instance.me.value;
    if (uid == null || me == null) return;
    final batch = _db.batch()
      ..update(_requests.doc(request.id), {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'seen': true,
      });
    if (!isFriend(request.senderId)) {
      batch.set(_friendships.doc(friendshipIdFor(uid, request.senderId)), {
        'users': [uid, request.senderId],
        'userDetails': {
          uid: _details(me),
          request.senderId: _details(request.sender),
        },
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    _commit(batch.commit(), "Couldn't accept the friend request");
  }

  void decline(FriendRequest request) {
    _commit(
      _requests.doc(request.id).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'seen': true,
      }),
      "Couldn't decline the friend request",
    );
  }

  void cancel(FriendRequest request) {
    _commit(
      _requests.doc(request.id).delete(),
      "Couldn't cancel the friend request",
    );
  }

  void remove(Friend friend) {
    _commit(
      _friendships.doc(friend.friendshipId).delete(),
      "Couldn't remove ${friend.displayName}",
    );
  }

  /// Clears the requests badge. Writes only the requests not yet seen.
  void markRequestsSeen() {
    final unseen = state.value.incoming.where((r) => !r.seen).toList();
    if (unseen.isEmpty) return;
    final batch = _db.batch();
    for (final request in unseen) {
      batch.update(_requests.doc(request.id), {'seen': true});
    }
    _commit(batch.commit(), null);
  }

  static Map<String, String> _details(UserProfile profile) => {
        'name': profile.name,
        'username': profile.username,
        'profilePic': profile.photoUrl,
      };

  void _commit(Future<void> write, String? failureMessage) {
    write.catchError((Object e) {
      debugPrint('FriendRepository: write failed: $e');
      if (failureMessage != null) AppMessenger.error(failureMessage);
    });
  }
}
