import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'user_chat_screen.dart';

class ChatList extends StatefulWidget {
  @override
  _ChatListState createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  Stream<QuerySnapshot>? _chatStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != null) {
      _fetchChats();
    } else {
      print("User is not authenticated");
    }
  }

  @override
  void dispose() {
    _chatStream = null;
    super.dispose();
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
        print("Error fetching chats: $error");
        return Stream<QuerySnapshot>.empty();
      });
    });
  }

  Future<void> _refreshChats() async {
    _fetchChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshChats,
        child: StreamBuilder<QuerySnapshot>(
          stream: _chatStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text("Error loading chats: ${snapshot.error}"));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text("No active chats yet."));
            }

            var chatDocs = snapshot.data!.docs;

            return ListView.builder(
              itemCount: chatDocs.length,
              itemBuilder: (context, index) {
                var chatData = chatDocs[index].data() as Map<String, dynamic>;
                Map<String, dynamic> users = chatData['users'] ?? {};
                String lastMessage = chatData['lastMessage'] ?? '';
                DateTime? timestamp = chatData['timestamp']?.toDate();

                // Get the other user's information
                String? otherUserId = users.keys.firstWhere(
                  (key) => key != _currentUserId,
                  orElse: () => '',
                );

                if (otherUserId.isEmpty) {
                  return SizedBox.shrink();
                }

                String? name = users[otherUserId]?['name'];
                String? username = users[otherUserId]?['username'];

                if (name == null || username == null) {
                  return SizedBox.shrink();
                }

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(name[0].toUpperCase()),
                  ),
                  title: Text(name),
                  subtitle: Text(lastMessage),
                  trailing: Text(
                    _formatMessageTime(timestamp),
                    style: TextStyle(color: Colors.grey),
                  ),
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

  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
