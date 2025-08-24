import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ChatModel {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final bool isRead;
  final String? otherUserProfilePic;
  final Map<String, dynamic> participants;
  final Map<String, dynamic> users;

  ChatModel({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.isRead,
    this.otherUserProfilePic,
    required this.participants,
    required this.users,
  });

  ChatModel copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    bool? isRead,
    String? otherUserName,
    String? otherUserProfilePic,
  }) {
    return ChatModel(
      chatId: this.chatId,
      otherUserId: this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      isRead: isRead ?? this.isRead,
      otherUserProfilePic: otherUserProfilePic ?? this.otherUserProfilePic,
      participants: this.participants,
      users: this.users,
    );
  }
}

class ChatCacheService {
  static final ChatCacheService _instance = ChatCacheService._internal();
  factory ChatCacheService() => _instance;
  ChatCacheService._internal();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for chats
  List<ChatModel> _cachedChats = [];
  bool _isInitialized = false;
  StreamSubscription<QuerySnapshot>? _chatSubscription;

  // User data cache
  final Map<String, Map<String, dynamic>> _userCache = {};

  // Stream controller for chat updates
  final StreamController<List<ChatModel>> _chatStreamController =
      StreamController<List<ChatModel>>.broadcast();

  Stream<List<ChatModel>> get chatStream => _chatStreamController.stream;
  List<ChatModel> get cachedChats => List.unmodifiable(_cachedChats);
  bool get isInitialized => _isInitialized;

  /// Initialize the chat cache for the current user
  Future<void> initializeCache() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _clearCache();
        return;
      }

      final currentUserId = currentUser.uid;

      // Cancel existing subscription
      await _chatSubscription?.cancel();

      // Set up real-time listener
      _chatSubscription = _firestore
          .collection('chats')
          .where('participants.$currentUserId', isEqualTo: true)
          .snapshots()
          .listen(
        (snapshot) async {
          await _updateCacheFromSnapshot(snapshot, currentUserId);
        },
        onError: (error) {
          print('Error in chat stream: $error');
        },
      );
    } catch (e) {
      print('Error initializing chat cache: $e');
    }
  }

  /// Update cache from Firestore snapshot
  Future<void> _updateCacheFromSnapshot(
      QuerySnapshot snapshot, String currentUserId) async {
    try {
      final newChats = <ChatModel>[];

      for (final doc in snapshot.docs) {
        final chatData = doc.data() as Map<String, dynamic>;
        final chatModel =
            await _createChatModelFromData(doc.id, chatData, currentUserId);
        if (chatModel != null) {
          newChats.add(chatModel);
        }
      }

      // Sort by last message time (newest first)
      newChats.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      _cachedChats = newChats;
      _isInitialized = true;

      // Notify listeners
      _chatStreamController.add(_cachedChats);
    } catch (e) {
      print('Error updating cache from snapshot: $e');
    }
  }

  /// Create ChatModel from Firestore data
  Future<ChatModel?> _createChatModelFromData(String chatId,
      Map<String, dynamic> chatData, String currentUserId) async {
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

      // Get other user data (with caching)
      final otherUserData = await _getUserData(otherUserId);
      String otherUserName =
          users[otherUserId]?['name'] ?? otherUserData['name'] ?? 'Unknown';

      final isRead = chatData['lastMessageSenderId'] == currentUserId ||
          (chatData['readBy'] != null &&
              chatData['readBy'][currentUserId] == true);

      return ChatModel(
        chatId: chatId,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        lastMessageSenderId: lastMessageSenderId,
        isRead: isRead,
        otherUserProfilePic: otherUserData['profilePictureUrl'],
        participants: participants,
        users: users,
      );
    } catch (e) {
      print('Error creating chat model: $e');
      return null;
    }
  }

  /// Get user data with caching
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        _userCache[userId] = doc.data() as Map<String, dynamic>;
        return _userCache[userId]!;
      }
      return {'name': 'Unknown User'};
    } catch (e) {
      print('Error getting user data: $e');
      return {'name': 'Unknown User'};
    }
  }

  /// Get a specific chat by chat ID
  ChatModel? getChatById(String chatId) {
    try {
      return _cachedChats.firstWhere((chat) => chat.chatId == chatId);
    } catch (e) {
      return null;
    }
  }

  /// Get a chat by other user ID
  ChatModel? getChatByUserId(String userId) {
    try {
      return _cachedChats.firstWhere((chat) => chat.otherUserId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Update a specific chat in cache (for optimistic updates)
  void updateChatInCache(
    String chatId, {
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    bool? isRead,
  }) {
    final index = _cachedChats.indexWhere((chat) => chat.chatId == chatId);
    if (index != -1) {
      _cachedChats[index] = _cachedChats[index].copyWith(
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        lastMessageSenderId: lastMessageSenderId,
        isRead: isRead,
      );

      // Re-sort after update
      _cachedChats.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      // Notify listeners
      _chatStreamController.add(_cachedChats);
    }
  }

  /// Force refresh cache
  Future<void> refreshCache() async {
    await initializeCache();
  }

  /// Clear cache (on logout)
  void _clearCache() {
    _cachedChats.clear();
    _userCache.clear();
    _isInitialized = false;
    _chatSubscription?.cancel();
    _chatStreamController.add(_cachedChats);
  }

  /// Clear cache and reinitialize
  Future<void> clearAndReinitialize() async {
    _clearCache();
    await initializeCache();
  }

  /// Dispose resources
  void dispose() {
    _chatSubscription?.cancel();
    _chatStreamController.close();
  }
}
