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

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser != null) {
      _fetchChats();
    } else {
      print("User is not authenticated");
    }
  }

  void _fetchChats() async {
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      setState(() {
        _chatStream = FirebaseFirestore.instance
            .collection('chats')
            .where('participants.$currentUserId', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .snapshots()
            .handleError((error) {
          print("Error fetching chats: $error");
        });
      });
    } catch (e) {
      print("Error in _fetchChats: $e");
    }
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
              return Center(child: Text("No chats yet."));
            }

            var chatDocs = snapshot.data!.docs;

            return ListView.builder(
              itemCount: chatDocs.length,
              itemBuilder: (context, index) {
                var chatData = chatDocs[index].data() as Map<String, dynamic>;
                Map<String, dynamic> users = chatData['users'] ?? {};
                String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

                // Get the other user's information
                String? otherUserId = users.keys.firstWhere(
                  (key) => key != currentUserId,
                  orElse: () => '',
                );

                if (otherUserId.isEmpty) {
                  return SizedBox.shrink();
                }

                String? name = users[otherUserId]?['name'];
                String lastMessage = chatData['lastMessage'] ?? "No messages yet";

                if (name == null) {
                  return SizedBox.shrink();
                }

                return ListTile(
                  title: Text(name),
                  subtitle: Text(lastMessage),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserChatScreen(
                          userId: otherUserId,
                          userName: name,
                        ),
                      ),
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
}