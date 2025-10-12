import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MessageDeleteService {
  // Singleton instance
  static final MessageDeleteService _instance =
      MessageDeleteService._internal();

  // Factory constructor
  factory MessageDeleteService() => _instance;

  // Internal constructor
  MessageDeleteService._internal();

  // Current user ID
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Delete a single message
  ///
  /// Returns true if deletion was successful
  Future<bool> deleteMessage({
    required String chatId,
    required String messageId,
    required BuildContext context,
  }) async {
    try {
      // Get the message document first
      final messageDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        _showErrorSnackBar(context, 'Message not found.');
        return false;
      }

      final messageData = messageDoc.data() as Map<String, dynamic>;
      final senderId = messageData['senderId'];

      // Only allow deletion if current user is the sender
      if (senderId != currentUserId) {
        _showErrorSnackBar(context, 'You can only delete your own messages.');
        return false;
      }

      // Delete the message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();

      // Update the last message in chat if this was the last message
      await _updateLastMessageIfNeeded(chatId, messageId);

      return true;
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to delete message: $e');
      return false;
    }
  }

  /// Delete a message for everyone (replaces with "message was deleted" text)
  Future<bool> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required BuildContext context,
  }) async {
    try {
      // Get the message document first
      final messageDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        _showErrorSnackBar(context, 'Message not found.');
        return false;
      }

      final messageData = messageDoc.data() as Map<String, dynamic>;
      final senderId = messageData['senderId'];

      // Only allow deletion if current user is the sender
      if (senderId != currentUserId) {
        _showErrorSnackBar(context, 'You can only delete your own messages.');
        return false;
      }

      // Update the message to show it was deleted
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'text': 'This message was deleted',
        'isDeleted': true,
        'isImage': false,
        'imageUrl': null,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      // If this was the last message, update it
      await _updateLastMessageIfNeededAfterPublicDelete(chatId, messageId);

      return true;
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to delete message: $e');
      return false;
    }
  }

  /// Update the last message after public deletion
  Future<void> _updateLastMessageIfNeededAfterPublicDelete(
      String chatId, String messageId) async {
    try {
      // Get chat document
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return;

      final chatData = chatDoc.data() as Map<String, dynamic>;
      final lastMsgSenderId = chatData['lastMessageSenderId'];

      // If the deleted message wasn't the last one, no need to update
      if (lastMsgSenderId != currentUserId) {
        return;
      }

      // Update the last message if it matches the deleted one
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'lastMessage': 'This message was deleted',
      });
    } catch (e) {
      print('Error updating last message after public delete: $e');
    }
  }

  /// Delete all messages for the current user in a chat
  ///
  /// This will delete all messages sent by the current user
  Future<bool> deleteAllUserMessages({
    required String chatId,
    required BuildContext context,
  }) async {
    try {
      // Query all messages sent by the current user
      final messagesQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: currentUserId)
          .get();

      // Check if there are any messages to delete
      if (messagesQuery.docs.isEmpty) {
        _showInfoSnackBar(context, 'No messages to delete.');
        return true;
      }

      // Use a batch to delete multiple messages
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Update the last message in chat
      await _updateLastMessageIfNeeded(chatId, null);

      _showSuccessSnackBar(context, 'All your messages have been deleted.');
      return true;
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to delete messages: $e');
      return false;
    }
  }

  /// Update the last message in the chat if needed
  Future<void> _updateLastMessageIfNeeded(
      String chatId, String? deletedMessageId) async {
    try {
      // Get chat document
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return;

      final chatData = chatDoc.data() as Map<String, dynamic>;

      // Check if the deleted message was the last message
      if (deletedMessageId != null) {
        final lastMsgSenderId = chatData['lastMessageSenderId'];

        // If the deleted message wasn't the last one, no need to update
        if (lastMsgSenderId != currentUserId) {
          return;
        }
      }

      // Get the new most recent message
      final messagesQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      // If no messages left, update with empty state
      if (messagesQuery.docs.isEmpty) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .update({
          'lastMessage': 'No messages',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': '',
        });
      } else {
        // Otherwise, update with the most recent message
        final lastMsg = messagesQuery.docs.first.data();
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .update({
          'lastMessage':
              lastMsg['isImage'] == true ? '[Photo]' : lastMsg['text'],
          'lastMessageTime': lastMsg['timestamp'],
          'lastMessageSenderId': lastMsg['senderId'],
        });
      }
    } catch (e) {
      print('Error updating last message: $e');
    }
  }

  // Helper for showing error message
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Helper for showing success message
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Helper for showing info message
  void _showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}
