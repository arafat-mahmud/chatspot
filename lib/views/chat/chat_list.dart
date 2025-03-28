import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_main/user_chat_screen.dart';

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
    if (_currentUserId != null) {
      _fetchChats();
    }
  }

  void _fetchChats() {
    if (_currentUserId == null) return;

    setState(() {
      _chatStream = FirebaseFirestore.instance
          .collection('chats')
          .where('participants.$_currentUserId', isEqualTo: true)
          .where('lastMessage', isNotEqualTo: '')
          .orderBy('timestamp', descending: true)
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
            if (snapshot.connectionState == ConnectionState.waiting && 
                _chatStream != null) {
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
              final users = chatData['users'] ?? {};
              final otherUserId = users.keys.firstWhere(
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
                final users = chatData['users'] ?? {};
                final lastMessage = chatData['lastMessage'] ?? '';
                final timestamp = chatData['timestamp']?.toDate();

                // Get the other user's information
                final otherUserId = users.keys.firstWhere(
                  (key) => key != _currentUserId,
                  orElse: () => '',
                );

                if (otherUserId.isEmpty) {
                  return const SizedBox.shrink();
                }

                final name = users[otherUserId]?['name'] ?? 'Unknown';
                
                // ignore: unused_local_variable
                final username = users[otherUserId]?['username'] ?? '';

                return _ChatListItem(
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

class _ChatListItem extends StatelessWidget {
  final String userId;
  final String name;
  final String lastMessage;
  final DateTime? timestamp;
  final VoidCallback onTap;

  const _ChatListItem({
    required this.userId,
    required this.name,
    required this.lastMessage,
    this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final profilePictureUrl = data?['profilePictureUrl'] as String?;

            if (profilePictureUrl?.isNotEmpty == true) {
              return CachedNetworkImage(
                imageUrl: profilePictureUrl!,
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  backgroundImage: imageProvider,
                  radius: 24,
                ),
                placeholder: (context, url) => CircleAvatar(
                  child: Text(name[0].toUpperCase()),
                  radius: 24,
                ),
                errorWidget: (context, url, error) => CircleAvatar(
                  child: Text(name[0].toUpperCase()),
                  radius: 24,
                ),
                fadeInDuration: const Duration(milliseconds: 200),
                fadeOutDuration: const Duration(milliseconds: 200),
                memCacheHeight: 96,
                memCacheWidth: 96,
              );
            }

            return CircleAvatar(
              child: Text(name[0].toUpperCase()),
              radius: 24,
            );
          },
        ),
      ),
      title: Text(name),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatMessageTime(timestamp),
        style: const TextStyle(color: Colors.grey),
      ),
      onTap: onTap,
    );
  }

  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}