import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:chatspot/services/friend/friend_aware_chat_service.dart';
import 'package:chatspot/services/chat_cache_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_list_item.dart';

class FriendChatList extends StatefulWidget {
  const FriendChatList({super.key});

  @override
  _FriendChatListState createState() => _FriendChatListState();
}

class _FriendChatListState extends State<FriendChatList> {
  String? _currentUserId;
  bool _isLoading = true;
  final ChatCacheService _chatCacheService = ChatCacheService();
  List<ChatModel> _cachedChats = [];
  bool _isInitialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final cachedChats = _chatCacheService.cachedChats;

      setState(() {
        _currentUserId = user.uid;
        _isLoading = false;
        if (cachedChats.isNotEmpty) {
          _cachedChats = cachedChats;
        }
      });

      // If the cache service is not initialized, initialize it
      if (!_chatCacheService.isInitialized) {
        await _chatCacheService.refreshCache();
      }

      // Listen to chat updates
      _listenToChatUpdates();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenToChatUpdates() {
    _chatCacheService.chatStream.listen((chats) {
      if (mounted) {
        setState(() {
          _cachedChats = chats;
          _isInitialLoadComplete = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_currentUserId == null) {
      return Center(child: Text('Please sign in to view chats'));
    }

    // Use cached chats if available while waiting for the first load
    if (_cachedChats.isNotEmpty) {
      return _buildChatList(_cachedChats);
    }

    // If no cached chats are available or if initial load is not complete, use stream
    if (!_isInitialLoadComplete) {
      return StreamBuilder<List<ChatModel>>(
        stream: FriendAwareChatService.getFriendChatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error);
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return _buildEmptyChatsWidget();
          }

          return _buildChatList(chats);
        },
      );
    }

    // If initial load is complete but there are no chats
    if (_cachedChats.isEmpty) {
      return _buildEmptyChatsWidget();
    }

    // Default case: show cached chats
    return _buildChatList(_cachedChats);
  }

  Widget _buildChatList(List<ChatModel> chats) {
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        return ChatListItem(
          userId: chat.otherUserId,
          name: chat.otherUserName,
          lastMessage: chat.lastMessage,
          timestamp: chat.lastMessageTime,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserChatScreen(
                  userId: chat.otherUserId,
                  userName: chat.otherUserName,
                ),
              ),
            );
          },
          currentUserId: _currentUserId!,
          chatId: chat.chatId,
          isRead: chat.isRead,
        );
      },
    );
  }

  Widget _buildErrorWidget(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Error loading chats'),
          SizedBox(height: 8),
          Text(
            '$error',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add friends to start chatting',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
