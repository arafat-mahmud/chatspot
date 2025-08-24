import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:chatspot/services/chat_cache_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_list_item.dart';

class ChatList extends StatefulWidget {
  const ChatList({super.key});

  @override
  _ChatListState createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  String? _currentUserId;
  late ChatCacheService _chatCache;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chatCache = ChatCacheService();
    _getCurrentUser();
  }

  @override
  void dispose() {
    // Don't dispose the cache service here as it's a singleton
    super.dispose();
  }

  void _getCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
      await _initializeChats();
    } else {
      // Listen for auth state changes in case user signs in later
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        if (user != null) {
          setState(() {
            _currentUserId = user.uid;
          });
          await _initializeChats();
        }
      });
    }
  }

  Future<void> _initializeChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _chatCache.initializeCache();
    } catch (e) {
      debugPrint("Error initializing chats: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshChats() async {
    await _chatCache.refreshCache();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshChats,
        color: Colors.blue,
        backgroundColor: Colors.white,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<ChatModel>>(
                stream: _chatCache.chatStream,
                initialData: _chatCache.cachedChats,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !_chatCache.isInitialized) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Error loading chats: ${snapshot.error}"),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshChats,
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    );
                  }

                  final chats = snapshot.data ?? [];

                  if (chats.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No active chats yet.",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Start a conversation by searching for users",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                          ).then((_) {
                            // Mark chat as read optimistically if user opened it
                            _chatCache.updateChatInCache(
                              chat.chatId,
                              isRead: true,
                            );
                          });
                        },
                        currentUserId: _currentUserId!,
                        chatId: chat.chatId,
                        isRead: chat.isRead,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
