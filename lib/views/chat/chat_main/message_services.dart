import 'package:cloud_firestore/cloud_firestore.dart';
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

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Add new message
      DocumentReference messageRef = chatRef.collection('messages').doc();
      batch.set(messageRef, {
        'text': message,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': currentUserId,
        'receiverId': receiverId,
        'isImage': false,
      });

      // Update chat document
      batch.set(
          chatRef,
          {
            'lastMessage': message,
            'lastMessageTime': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      await batch.commit();
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
      });

      // Update chat document
      batch.set(
          chatRef,
          {
            'lastMessage': '[Photo]',
            'lastMessageTime': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('Error sending image message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image')),
      );
      rethrow;
    }
  }
}