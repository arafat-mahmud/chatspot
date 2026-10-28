import 'package:cloud_firestore/cloud_firestore.dart';

/// `chats/{a-b}`: one per pair of users, ids sorted and joined by "-".
String chatIdFor(String a, String b) =>
    (a.compareTo(b) < 0) ? '$a-$b' : '$b-$a';

DateTime? _time(Object? value, {required bool pending}) {
  if (value is Timestamp) return value.toDate();
  // Our own write the server hasn't stamped yet.
  return pending ? DateTime.now() : null;
}

/// One row of the chat list.
class ChatSummary {
  const ChatSummary({
    required this.chatId,
    required this.peerId,
    required this.peerName,
    required this.peerPhotoUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    required this.unreadCount,
    required this.myLastRead,
    required this.peerLastRead,
  });

  final String chatId;
  final String peerId;
  final String peerName;
  final String peerPhotoUrl;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastSenderId;
  final int unreadCount;
  final DateTime? myLastRead;

  /// When the peer last opened the chat; drives the "Seen" receipt.
  final DateTime? peerLastRead;

  bool get hasUnread => unreadCount > 0;

  ChatSummary copyWith({String? peerName, String? peerPhotoUrl}) =>
      ChatSummary(
        chatId: chatId,
        peerId: peerId,
        peerName: peerName ?? this.peerName,
        peerPhotoUrl: peerPhotoUrl ?? this.peerPhotoUrl,
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        lastSenderId: lastSenderId,
        unreadCount: unreadCount,
        myLastRead: myLastRead,
        peerLastRead: peerLastRead,
      );

  static ChatSummary? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String selfId,
  ) {
    final data = doc.data();
    if (data == null) return null;
    final pending = doc.metadata.hasPendingWrites;

    final participants = (data['participants'] as Map?)?.keys ??
        (data['participantIds'] as List? ?? const []);
    final peerId = participants
        .map((id) => '$id')
        .firstWhere((id) => id != selfId, orElse: () => '');
    if (peerId.isEmpty) return null;

    final peer = (data['users'] as Map?)?[peerId] as Map? ?? const {};
    final lastRead = data['lastRead'] as Map? ?? const {};
    final lastSenderId = data['lastMessageSenderId'] as String? ?? '';
    final lastMessageTime = _time(data['lastMessageTime'], pending: pending);
    final myLastRead = _time(lastRead[selfId], pending: pending);

    final unread = (data['unread'] as Map?)?[selfId];
    final int unreadCount;
    if (unread is num) {
      unreadCount = unread.toInt();
    } else {
      // Chats from before unread counters: derive a dot from read state.
      final legacyRead = (data['readBy'] as Map?)?[selfId] == true;
      final newer = lastMessageTime != null &&
          (myLastRead == null || lastMessageTime.isAfter(myLastRead));
      unreadCount =
          lastSenderId != selfId && !legacyRead && newer ? 1 : 0;
    }

    return ChatSummary(
      chatId: doc.id,
      peerId: peerId,
      peerName: peer['name'] as String? ?? '',
      peerPhotoUrl: peer['photoUrl'] as String? ?? '',
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageTime: lastMessageTime,
      lastSenderId: lastSenderId,
      unreadCount: unreadCount,
      myLastRead: myLastRead,
      peerLastRead: _time(lastRead[peerId], pending: false),
    );
  }
}

/// One message in `chats/{id}/messages/{messageId}`.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.imageUrl,
    required this.isImage,
    required this.isDeleted,
    required this.timestamp,
    required this.pending,
  });

  final String id;
  final String senderId;
  final String text;
  final String imageUrl;
  final bool isImage;
  final bool isDeleted;
  final DateTime? timestamp;

  /// Not yet confirmed by the server (sending, or queued while offline).
  final bool pending;

  static ChatMessage fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final pending = doc.metadata.hasPendingWrites;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      isImage: data['isImage'] == true,
      isDeleted: data['isDeleted'] == true,
      timestamp: _time(data['timestamp'], pending: pending),
      pending: pending,
    );
  }
}
