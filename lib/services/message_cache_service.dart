import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.imageUrl,
    this.metadata,
    required this.isRead,
  });
}

class MessageCacheService {
  static final MessageCacheService _instance = MessageCacheService._internal();
  factory MessageCacheService() => _instance;
  MessageCacheService._internal();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache structure: Map<chatId, List<MessageModel>>
  final Map<String, List<MessageModel>> _cachedMessages = {};

  // Stream controllers for each chat
  final Map<String, StreamController<List<MessageModel>>>
      _messageStreamControllers = {};

  // Active subscriptions
  final Map<String, StreamSubscription<QuerySnapshot>> _messageSubscriptions =
      {};

  // Get cached messages for a chat
  List<MessageModel>? getCachedMessages(String chatId) {
    return _cachedMessages[chatId]?.toList();
  }

  // Get stream of messages for a chat
  Stream<List<MessageModel>> getMessageStream(String chatId) {
    // Create controller if it doesn't exist
    if (!_messageStreamControllers.containsKey(chatId)) {
      _messageStreamControllers[chatId] =
          StreamController<List<MessageModel>>.broadcast();

      // Setup the stream if not already set up
      _setupMessageStream(chatId);
    }

    return _messageStreamControllers[chatId]!.stream;
  }

  // Setup message stream for a chat
  void _setupMessageStream(String chatId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Cancel existing subscription if any
    _messageSubscriptions[chatId]?.cancel();

    // Set up real-time listener
    _messageSubscriptions[chatId] = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _updateMessageCache(chatId, snapshot);
      },
      onError: (error) {
        print('Error in messages stream for $chatId: $error');
      },
    );
  }

  // Update message cache from snapshot
  void _updateMessageCache(String chatId, QuerySnapshot snapshot) {
    try {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        return MessageModel(
          id: doc.id,
          senderId: data['senderId'] ?? '',
          text: data['text'] ?? '',
          timestamp: data['timestamp']?.toDate() ?? DateTime.now(),
          imageUrl: data['imageUrl'],
          metadata: data['metadata'],
          isRead: data['isRead'] ?? false,
        );
      }).toList();

      // Update cache
      _cachedMessages[chatId] = messages;

      // Notify listeners
      if (_messageStreamControllers.containsKey(chatId)) {
        _messageStreamControllers[chatId]!.add(messages);
      }
    } catch (e) {
      print('Error updating message cache: $e');
    }
  }

  // Add a new message to the cache (for optimistic updates)
  void addMessageToCache(String chatId, MessageModel message) {
    if (!_cachedMessages.containsKey(chatId)) {
      _cachedMessages[chatId] = [];
    }

    // Add message to cache
    _cachedMessages[chatId]!
        .insert(0, message); // Add at the beginning (most recent)

    // Notify listeners
    if (_messageStreamControllers.containsKey(chatId)) {
      _messageStreamControllers[chatId]!.add(_cachedMessages[chatId]!);
    }
  }

  // Mark messages as read in a chat
  void markMessagesAsRead(String chatId, String currentUserId) {
    if (!_cachedMessages.containsKey(chatId)) return;

    bool hasChanges = false;
    final updatedMessages = _cachedMessages[chatId]!.map((message) {
      if (message.senderId != currentUserId && !message.isRead) {
        hasChanges = true;
        return MessageModel(
          id: message.id,
          senderId: message.senderId,
          text: message.text,
          timestamp: message.timestamp,
          imageUrl: message.imageUrl,
          metadata: message.metadata,
          isRead: true,
        );
      }
      return message;
    }).toList();

    if (hasChanges) {
      // Update cache
      _cachedMessages[chatId] = updatedMessages;

      // Notify listeners
      if (_messageStreamControllers.containsKey(chatId)) {
        _messageStreamControllers[chatId]!.add(updatedMessages);
      }
    }
  }

  // Refresh cache for a chat
  Future<void> refreshCache(String chatId) async {
    _messageSubscriptions[chatId]?.cancel();
    _setupMessageStream(chatId);
  }

  // Clear cache for a chat
  void clearCache(String chatId) {
    _cachedMessages.remove(chatId);
    _messageSubscriptions[chatId]?.cancel();
    _messageSubscriptions.remove(chatId);

    // Close and remove stream controller
    _messageStreamControllers[chatId]?.close();
    _messageStreamControllers.remove(chatId);
  }

  // Clear all caches
  void clearAllCaches() {
    for (var subscription in _messageSubscriptions.values) {
      subscription.cancel();
    }

    for (var controller in _messageStreamControllers.values) {
      controller.close();
    }

    _cachedMessages.clear();
    _messageSubscriptions.clear();
    _messageStreamControllers.clear();
  }

  // Dispose resources
  void dispose() {
    clearAllCaches();
  }
}
