import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatspot/services/chat_cache_service.dart';
import 'package:chatspot/services/friend/friend_request_service.dart';

class FriendAwareChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get only friend chats for the current user
  static Stream<List<ChatModel>> getFriendChatsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    final currentUserId = currentUser.uid;

    return _firestore
        .collection('chats')
        .where('participants.$currentUserId', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<ChatModel> friendChats = [];

      for (final doc in snapshot.docs) {
        final chatData = doc.data();
        final participants =
            chatData['participants'] as Map<String, dynamic>? ?? {};

        // Find other user
        final otherUserId = participants.keys.firstWhere(
          (key) => key != currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          // Check if they are friends
          final areFriends =
              await FriendRequestService.areFriends(currentUserId, otherUserId);

          if (areFriends) {
            // Create chat model
            final chatModel =
                await _createChatModelFromData(doc.id, chatData, currentUserId);
            if (chatModel != null) {
              friendChats.add(chatModel);
            }
          }
        }
      }

      // Sort by last message time (newest first)
      friendChats.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      return friendChats;
    });
  }

  /// Create ChatModel from Firestore data
  static Future<ChatModel?> _createChatModelFromData(
    String chatId,
    Map<String, dynamic> chatData,
    String currentUserId,
  ) async {
    try {
      final participants =
          chatData['participants'] as Map<String, dynamic>? ?? {};
      final users = chatData['users'] as Map<String, dynamic>? ?? {};
      final lastMessage = chatData['lastMessage'] ?? '';
      final lastMessageTime = chatData['lastMessageTime']?.toDate();
      final lastMessageSenderId = chatData['lastMessageSenderId'] ?? '';

      // Find other user
      final otherUserId = participants.keys.firstWhere(
        (key) => key != currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) return null;

      // Get other user data
      String otherUserName = 'Unknown User';
      String? otherUserProfilePic;

      if (users.containsKey(otherUserId)) {
        final userData = users[otherUserId] as Map<String, dynamic>;
        otherUserName = userData['name'] ?? 'Unknown User';
      } else {
        // Fallback: get from users collection
        try {
          final userDoc =
              await _firestore.collection('users').doc(otherUserId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            otherUserName = userData['name'] ?? 'Unknown User';
            otherUserProfilePic = userData['profilePictureUrl'];
          }
        } catch (e) {
          print('Error getting user data: $e');
        }
      }

      // Check read status
      final readBy = chatData['readBy'] as Map<String, dynamic>? ?? {};
      final isRead =
          readBy[currentUserId] == true || lastMessageSenderId == currentUserId;

      return ChatModel(
        chatId: chatId,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        lastMessageSenderId: lastMessageSenderId,
        isRead: isRead,
        otherUserProfilePic: otherUserProfilePic,
        participants: participants,
        users: users,
      );
    } catch (e) {
      print('Error creating chat model: $e');
      return null;
    }
  }

  /// Check if user can chat with another user (they must be friends)
  static Future<bool> canChatWith(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    return await FriendRequestService.areFriends(currentUser.uid, otherUserId);
  }
}
