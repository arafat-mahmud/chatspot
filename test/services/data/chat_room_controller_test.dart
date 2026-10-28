import 'package:chatspot/services/chat/chat_room_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late CollectionReference<Map<String, dynamic>> messages;
  final start = DateTime(2026, 1, 1);

  Future<void> addMessage(int i) => messages.doc('m$i').set({
        'text': 'message $i',
        'senderId': i.isEven ? 'a' : 'b',
        'timestamp': Timestamp.fromDate(start.add(Duration(minutes: i))),
      });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    db = FakeFirebaseFirestore();
    messages = db.collection('chats').doc('a-b').collection('messages');
    for (var i = 0; i < 75; i++) {
      await addMessage(i);
    }
  });

  test('opens with only the newest page', () async {
    final room = ChatRoomController('a-b', firestore: db)..start();
    await settle();

    expect(room.loaded, isTrue);
    expect(room.messages, hasLength(ChatRoomController.pageSize));
    expect(room.messages.first.id, 'm74');
    expect(room.hasMore, isTrue);
    room.dispose();
  });

  test('loads older pages until the beginning', () async {
    final room = ChatRoomController('a-b', firestore: db)..start();
    await settle();

    await room.loadMore();
    expect(room.messages, hasLength(60));
    expect(room.hasMore, isTrue);

    await room.loadMore();
    expect(room.messages, hasLength(75));
    expect(room.messages.last.id, 'm0');
    expect(room.hasMore, isFalse);

    final ids = room.messages.map((m) => m.id).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'no duplicates');
    room.dispose();
  });

  test('keeps a message pushed out of the live window by a new one',
      () async {
    final room = ChatRoomController('a-b', firestore: db)..start();
    await settle();

    await addMessage(75);
    await settle();

    expect(room.messages.first.id, 'm75');
    expect(room.messages, hasLength(31));
    expect(room.messages.map((m) => m.id), contains('m45'));

    // Paging continues below the oldest message we hold.
    await room.loadMore();
    expect(room.messages, hasLength(61));
    final ids = room.messages.map((m) => m.id).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'no duplicates');
    room.dispose();
  });

  test('a short chat has nothing more to load', () async {
    final short = db.collection('chats').doc('a-c').collection('messages');
    await short.doc('x').set({
      'text': 'hi',
      'senderId': 'a',
      'timestamp': Timestamp.fromDate(start),
    });
    final room = ChatRoomController('a-c', firestore: db)..start();
    await settle();

    expect(room.messages, hasLength(1));
    expect(room.hasMore, isFalse);
    room.dispose();
  });
}
