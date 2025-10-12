import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:chatspot/services/chat_cache_service.dart';

class ConversationDeleteService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Delete an entire conversation with a user including all chat history
  static Future<bool> deleteConversation({
    required String chatId,
    required String otherUserId,
    required String otherUserName,
    BuildContext? context,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (context != null && context.mounted) {
          _showErrorSnackBar(context, 'User not authenticated');
        }
        return false;
      }

      final currentUserId = currentUser.uid;

      // Delete messages in smaller batches to avoid timeout
      await _deleteMessagesInBatches(chatId);

      // Delete the chat document
      await _firestore.collection('chats').doc(chatId).delete();

      // Remove chat reference from both users' chatList
      await _removeChatFromUserLists(currentUserId, otherUserId);

      // Update the local cache to remove the deleted chat
      final chatCache = ChatCacheService();
      await chatCache.refreshCache();

      if (context != null && context.mounted) {
        _showSuccessSnackBar(
            context, 'Conversation with $otherUserName deleted');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      if (context != null && context.mounted) {
        _showErrorSnackBar(context, 'Failed to delete conversation');
      }
      return false;
    }
  }

  /// Delete messages in smaller batches to avoid Firestore limits
  static Future<void> _deleteMessagesInBatches(String chatId) async {
    const batchSize = 100; // Firestore batch limit is 500, using 100 for safety

    while (true) {
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .limit(batchSize)
          .get();

      if (messagesQuery.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final messageDoc in messagesQuery.docs) {
        batch.delete(messageDoc.reference);
      }

      await batch.commit();
    }
  }

  /// Remove chat references from both users' chat lists
  static Future<void> _removeChatFromUserLists(
      String currentUserId, String otherUserId) async {
    try {
      // Remove from current user's chatList
      await _firestore.collection('users').doc(currentUserId).update({
        'chatList.$otherUserId': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Failed to update current user chatList: $e');
    }

    try {
      // Remove from other user's chatList
      await _firestore.collection('users').doc(otherUserId).update({
        'chatList.$currentUserId': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Failed to update other user chatList: $e');
    }
  }

  /// Show confirmation dialog before deleting conversation
  static Future<bool?> showDeleteConversationDialog({
    required BuildContext context,
    required String otherUserName,
    required ThemeData theme,
  }) async {
    final isDarkMode = theme.brightness == Brightness.dark;

    return await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Warning icon and title
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Delete conversation?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Warning message
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This will permanently delete:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• All messages with $otherUserName\n• All photos and media shared\n• The entire chat history',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This action cannot be undone.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Failed to show success snackbar: $e');
    }
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('Failed to show error snackbar: $e');
    }
  }
}
