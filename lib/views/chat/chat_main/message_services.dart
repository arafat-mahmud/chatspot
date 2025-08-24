import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatspot/services/chat_cache_service.dart';
import 'package:flutter/material.dart';

class MessageServices {
  static Future<void> sendTextMessage({
    required String chatId,
    required String currentUserId,
    required String receiverId,
    required String message,
    required BuildContext context,
  }) async {
    try {
      DocumentReference chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);

      // Get user data for both participants
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final receiverUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Add new message
      DocumentReference messageRef = chatRef.collection('messages').doc();
      batch.set(messageRef, {
        'text': message,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': currentUserId,
        'receiverId': receiverId,
        'isImage': false,
        'seenBy': {}, // Initialize empty seenBy map
      });

      // Update chat document with message info and user data
      batch.set(
          chatRef,
          {
            'lastMessage': message,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSenderId': currentUserId,
            'users': {
              currentUserId: {
                'name': currentUserDoc.data()?['name'] ?? 'Unknown',
                // Add other user fields if needed
              },
              receiverId: {
                'name': receiverUserDoc.data()?['name'] ?? 'Unknown',
                // Add other user fields if needed
              }
            }
          },
          SetOptions(merge: true));

      await batch.commit();

      // Update cache optimistically
      ChatCacheService().updateChatInCache(
        chatId,
        lastMessage: message,
        lastMessageTime: DateTime.now(),
        lastMessageSenderId: currentUserId,
      );
    } catch (e) {
      print("Error sending message: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send message")),
      );
      rethrow;
    }
  }

  static Future<void> sendImageMessage({
    required String chatId,
    required String currentUserId,
    required String receiverId,
    required String imageUrl,
    required BuildContext context,
  }) async {
    try {
      DocumentReference chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);

      // Get user data for both participants
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final receiverUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Add new message
      DocumentReference messageRef = chatRef.collection('messages').doc();
      batch.set(messageRef, {
        'text': '',
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': currentUserId,
        'receiverId': receiverId,
        'isImage': true,
        'seenBy': {}, // Initialize empty seenBy map
      });

      // Update chat document with user data
      batch.set(
          chatRef,
          {
            'lastMessage': '[Photo]',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSenderId': currentUserId,
            'users': {
              currentUserId: {
                'name': currentUserDoc.data()?['name'] ?? 'Unknown',
                // Add other user fields if needed
              },
              receiverId: {
                'name': receiverUserDoc.data()?['name'] ?? 'Unknown',
                // Add other user fields if needed
              }
            }
          },
          SetOptions(merge: true));

      await batch.commit();

      // Update cache optimistically
      ChatCacheService().updateChatInCache(
        chatId,
        lastMessage: '[Photo]',
        lastMessageTime: DateTime.now(),
        lastMessageSenderId: currentUserId,
      );
    } catch (e) {
      debugPrint('Error sending image message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image')),
      );
      rethrow;
    }
  }

  // Add this new method to mark message as seen
  static Future<void> markMessageAsSeen({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'seenBy.$userId': true,
      });
    } catch (e) {
      debugPrint('Error marking message as seen: $e');
      rethrow;
    }
  }
}
