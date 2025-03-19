import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class UserChatScreen extends StatefulWidget {
  final String userId;
  final String userName;

  UserChatScreen({Key? key, required this.userId, required this.userName}) : super(key: key);

  @override
  _UserChatScreenState createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isEmojiVisible = false;

  String get currentUserId => FirebaseAuth.instance.currentUser!.uid;

  String get chatId {
    List<String> ids = [currentUserId, widget.userId];
    ids.sort();
    return ids.join("-");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        actions: [
          IconButton(icon: Icon(Icons.video_call), onPressed: () {}),
          IconButton(icon: Icon(Icons.call), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index];
                    bool isUser = msg['senderId'] == currentUserId;
                    String messageText = msg['text'];
                    bool isShortMessage = messageText.length <= 5;
                    
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                        decoration: BoxDecoration(
                          color: isUser ? Color.fromARGB(231, 11, 167, 244) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomLeft: isUser ? Radius.circular(20) : Radius.circular(0),
                            bottomRight: isUser ? Radius.circular(22) : Radius.circular(20),
                          ),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: isShortMessage
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    messageText,
                                    style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0)),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    _formatTimestamp(msg['timestamp']?.toDate()),
                                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    messageText,
                                    style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0)),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    _formatTimestamp(msg['timestamp']?.toDate()),
                                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isEmojiVisible)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  setState(() {
                    _messageController.text += emoji.emoji;
                  });
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onTap: () {
                      setState(() {
                        _isEmojiVisible = false;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      prefixIcon: IconButton(
                        icon: Icon(Icons.emoji_emotions),
                        onPressed: () {
                          setState(() {
                            _isEmojiVisible = !_isEmojiVisible;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
          'text': message,
          'timestamp': FieldValue.serverTimestamp(),
          'senderId': currentUserId,
          'receiverId': widget.userId,
        });

        _messageController.clear();
        _scrollToBottom();
      } catch (e) {
        print("Error sending message: $e");
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 300), () {
      _scrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return "";
    String hour = timestamp.hour % 12 == 0 ? '12' : (timestamp.hour % 12).toString();
    String minute = timestamp.minute.toString().padLeft(2, '0');
    String period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }
}
