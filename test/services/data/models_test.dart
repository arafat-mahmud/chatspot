import 'package:chatspot/services/chat/chat_models.dart';
import 'package:chatspot/services/friend/friend_models.dart';
import 'package:chatspot/services/friend/friend_repository.dart';
import 'package:chatspot/services/user/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ids', () {
    test('chat ids are the same from both sides', () {
      expect(chatIdFor('b', 'a'), 'a-b');
      expect(chatIdFor('a', 'b'), 'a-b');
    });

    test('friendship ids are the same from both sides', () {
      expect(FriendRepository.friendshipIdFor('y', 'x'), 'x_y');
      expect(FriendRepository.friendshipIdFor('x', 'y'), 'x_y');
    });
  });

  group('UserProfile', () {
    test('survives the disk cache round trip', () {
      const profile = UserProfile(
        uid: 'u1',
        name: 'Ada',
        username: '@ada',
        photoUrl: 'https://p',
        email: 'ada@x.io',
        dob: '1990-01-01',
        nameLower: 'ada',
        emailVerified: true,
      );
      final copy = UserProfile.fromJson(profile.toJson());
      expect(copy.toJson(), profile.toJson());
    });

    test('tolerates missing and mistyped fields', () {
      final profile =
          UserProfile.fromMap('u1', {'name': 42, 'username': null});
      expect(profile.name, '');
      expect(profile.displayName, 'Unknown');
      expect(profile.hasUsername, isFalse);
    });

    test('seeded public fields keep private ones', () {
      const full = UserProfile(
          uid: 'u1', name: 'Old', email: 'a@b.c', dob: '2000-01-01');
      final merged = full.withPublicFieldsOf(
          const UserProfile(uid: 'u1', name: 'New', photoUrl: 'p'));
      expect(merged.name, 'New');
      expect(merged.photoUrl, 'p');
      expect(merged.email, 'a@b.c');
      expect(merged.dob, '2000-01-01');
    });
  });

  group('ChatSummary.fromDoc', () {
    late FakeFirebaseFirestore db;
    setUp(() => db = FakeFirebaseFirestore());

    Future<DocumentSnapshot<Map<String, dynamic>>> chat(
        Map<String, dynamic> data) async {
      await db.collection('chats').doc('a-b').set(data);
      return db.collection('chats').doc('a-b').get();
    }

    test('reads the unread counter and read receipts', () async {
      final read = DateTime(2026, 1, 1, 12);
      final summary = ChatSummary.fromDoc(
        await chat({
          'participants': {'a': true, 'b': true},
          'users': {
            'b': {'name': 'Bob', 'photoUrl': 'p'}
          },
          'lastMessage': 'hey',
          'lastMessageTime': Timestamp.fromDate(read),
          'lastMessageSenderId': 'b',
          'unread': {'a': 3, 'b': 0},
          'lastRead': {'b': Timestamp.fromDate(read)},
        }),
        'a',
      )!;
      expect(summary.peerId, 'b');
      expect(summary.peerName, 'Bob');
      expect(summary.unreadCount, 3);
      expect(summary.peerLastRead, read);
    });

    test('older chats without counters get an unread dot', () async {
      final summary = ChatSummary.fromDoc(
        await chat({
          'participantIds': ['a', 'b'],
          'lastMessageTime': Timestamp.fromDate(DateTime(2026)),
          'lastMessageSenderId': 'b',
        }),
        'a',
      )!;
      expect(summary.unreadCount, 1);
    });

    test('our own last message is never unread', () async {
      final summary = ChatSummary.fromDoc(
        await chat({
          'participantIds': ['a', 'b'],
          'lastMessageTime': Timestamp.fromDate(DateTime(2026)),
          'lastMessageSenderId': 'a',
        }),
        'a',
      )!;
      expect(summary.hasUnread, isFalse);
    });

    test('legacy readBy marks a chat read', () async {
      final summary = ChatSummary.fromDoc(
        await chat({
          'participants': {'a': true, 'b': true},
          'lastMessageTime': Timestamp.fromDate(DateTime(2026)),
          'lastMessageSenderId': 'b',
          'readBy': {'a': true},
        }),
        'a',
      )!;
      expect(summary.hasUnread, isFalse);
    });
  });

  group('friend documents', () {
    test('Friend picks the other user and their details', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('friendships').doc('f1').set({
        'users': ['me', 'them'],
        'userDetails': {
          'them': {'name': 'Them', 'username': '@them', 'profilePic': 'p'},
        },
      });
      final friend =
          Friend.fromDoc(await db.collection('friendships').doc('f1').get(), 'me')!;
      expect(friend.uid, 'them');
      expect(friend.displayName, 'Them');
      expect(friend.photoUrl, 'p');
    });

    test('FriendsState answers lookups and counts unseen requests', () {
      FriendRequest request(String id, String from, bool seen) => FriendRequest(
            id: id,
            senderId: from,
            receiverId: 'me',
            sender: UserProfile(uid: from),
            receiver: const UserProfile(uid: 'me'),
            sentAt: null,
            seen: seen,
          );
      final state = FriendsState(
        friends: const [
          Friend(
              friendshipId: 'f',
              uid: 'x',
              name: 'X',
              username: '',
              photoUrl: ''),
        ],
        incoming: [request('r1', 'y', false), request('r2', 'z', true)],
        loaded: true,
      );
      expect(state.friend('x'), isNotNull);
      expect(state.friend('y'), isNull);
      expect(state.incomingFrom('y')?.id, 'r1');
      expect(state.unseenCount, 1);
    });
  });
}
