// chat_list.dart
import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_list_item.dart'; // Import the separated widget

class ChatList extends StatefulWidget {
  const ChatList({super.key});

  @override
  _ChatListState createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  Stream<QuerySnapshot>? _chatStream;
  String? _currentUserId;
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _fetchChats();
  }

  void _fetchChats() {
    if (_currentUserId == null) {
      debugPrint("Current user ID is null");
      return;
    }

    setState(() {
      _chatStream = FirebaseFirestore.instance
          .collection('chats')
          .where('participants.$_currentUserId', isEqualTo: true)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .handleError((error) {
        debugPrint("Error fetching chats: $error");
        return Stream<QuerySnapshot>.empty();
      });
    });
  }

  Future<void> _refreshChats() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _fetchChats();
  }

  Future<void> _precacheUserData(String userId) async {
    if (_userCache.containsKey(userId)) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        _userCache[userId] = doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error precaching user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshChats,
        color: Colors.blue,
        backgroundColor: Colors.white,
        child: StreamBuilder<QuerySnapshot>(
          stream: _chatStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Center(
                child: Text("Error loading chats: ${snapshot.error}"),
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No active chats yet."));
            }

            final chatDocs = snapshot.data!.docs;

            // Precache user data for all chats
            for (final doc in chatDocs) {
              final chatData = doc.data() as Map<String, dynamic>;
              final participants = chatData['participants'] ?? {};
              // ignore: unused_local_variable
              final users = chatData['users'] ?? {};
              
              // Find other user ID
              final otherUserId = participants.keys.firstWhere(
                (key) => key != _currentUserId,
                orElse: () => '',
              );
              
              if (otherUserId.isNotEmpty) {
                _precacheUserData(otherUserId);
              }
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: chatDocs.length,
              itemBuilder: (context, index) {
                final chatData = chatDocs[index].data() as Map<String, dynamic>;
                final participants = chatData['participants'] ?? {};
                final users = chatData['users'] ?? {};
                final lastMessage = chatData['lastMessage'] ?? '';
                final timestamp = chatData['lastMessageTime']?.toDate();

                // Get the other user's information
                final otherUserId = participants.keys.firstWhere(
                  (key) => key != _currentUserId,
                  orElse: () => '',
                );

                if (otherUserId.isEmpty) {
                  return const SizedBox.shrink();
                }

                final name = users[otherUserId]?['name'] ?? 'Unknown';
                
                return ChatListItem( // Now using the separated widget
                  userId: otherUserId,
                  name: name,
                  lastMessage: lastMessage,
                  timestamp: timestamp,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserChatScreen(
                          userId: otherUserId,
                          userName: name,
                        ),
                      ),
                    ).then((_) => _refreshChats());
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}