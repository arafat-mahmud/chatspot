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
    _getCurrentUser();
  }

  void _getCurrentUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
      _fetchChats();
    } else {
      // Listen for auth state changes in case user signs in later
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          setState(() {
            _currentUserId = user.uid;
          });
          _fetchChats();
        }
      });
    }
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

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        _userCache[userId] = doc.data() as Map<String, dynamic>;
        return _userCache[userId]!;
      }
      return {'name': 'Unknown User'};
    } catch (e) {
      debugPrint("Error getting user data: $e");
      return {'name': 'Unknown User'};
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

            final chatDocs = snapshot.data!.docs.toList();

            // Sort chats by lastMessageTime on client side (newest first)
            chatDocs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['lastMessageTime'] as Timestamp?;
              final bTime = bData['lastMessageTime'] as Timestamp?;

              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;

              return bTime.compareTo(aTime);
            });

            return FutureBuilder(
              future: _precacheAllUserData(chatDocs),
              builder: (context, precacheSnapshot) {
                if (precacheSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: chatDocs.length,
                  itemBuilder: (context, index) {
                    final chatData =
                        chatDocs[index].data() as Map<String, dynamic>;
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

                    // Get name from users map in chat document or fetch from user collection
                    String name = users[otherUserId]?['name'] ?? 'Unknown';

                    // If name is unknown, try to get it from cache or fetch it
                    if (name == 'Unknown' &&
                        _userCache.containsKey(otherUserId)) {
                      name = _userCache[otherUserId]!['name'] ?? 'Unknown';
                    }

                    return ChatListItem(
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
                      currentUserId: _currentUserId!,
                      chatId: chatDocs[index].id,
                      isRead:
                          chatData['lastMessageSenderId'] == _currentUserId ||
                              (chatData['readBy'] != null &&
                                  chatData['readBy'][_currentUserId] == true),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _precacheAllUserData(
      List<QueryDocumentSnapshot> chatDocs) async {
    final futures = <Future>[];

    for (final doc in chatDocs) {
      final chatData = doc.data() as Map<String, dynamic>;
      final participants = chatData['participants'] ?? {};

      // Find other user ID
      final otherUserId = participants.keys.firstWhere(
        (key) => key != _currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isNotEmpty) {
        futures.add(_getUserData(otherUserId));
      }
    }

    await Future.wait(futures);
  }
}
