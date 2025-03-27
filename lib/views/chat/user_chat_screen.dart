import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class UserChatScreen extends StatefulWidget {
  final String userId;
  final String userName;

  UserChatScreen({Key? key, required this.userId, required this.userName})
      : super(key: key);

  @override
  _UserChatScreenState createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isEmojiVisible = false;
  bool _isSending = false;

  String get currentUserId => FirebaseAuth.instance.currentUser!.uid;

  String get chatId {
    List<String> ids = [currentUserId, widget.userId];
    ids.sort();
    return ids.join("-");
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_isEmojiVisible) {
      setState(() {
        _isEmojiVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        actions: [
          IconButton(
            icon: Icon(Icons.video_call),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                    DateTime? timestamp = msg['timestamp']?.toDate();
                    bool isUser = msg['senderId'] == currentUserId;
                    String messageText = msg['text'];
                    bool isShortMessage = messageText.length <= 5;

                    bool showDateHeader = false;

                    if (index == messages.length - 1) {
                      showDateHeader = true;
                    } else {
                      var prevMsg = messages[index + 1];
                      DateTime? prevTimestamp = prevMsg['timestamp']?.toDate();

                      if (prevTimestamp != null && timestamp != null) {
                        if (timestamp.day != prevTimestamp.day ||
                            timestamp.month != prevTimestamp.month ||
                            timestamp.year != prevTimestamp.year) {
                          showDateHeader = true;
                        }
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                _formatDate(timestamp),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 8.0),
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 7.0),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Color.fromARGB(231, 11, 69, 244)
                                  : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomLeft: isUser
                                    ? Radius.circular(20)
                                    : Radius.circular(0),
                                bottomRight: isUser
                                    ? Radius.circular(22)
                                    : Radius.circular(20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(
                                      red: 0.2, green: 0.2, blue: 0.2),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            child: isShortMessage
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        messageText,
                                        style: TextStyle(
                                          color: isUser
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        _formatTimestamp(timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isUser
                                              ? Colors.white.withOpacity(0.8)
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        messageText,
                                        style: TextStyle(
                                          color: isUser
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        _formatTimestamp(timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isUser
                                              ? Colors.white.withOpacity(0.8)
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
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
                IconButton(
                  icon: Icon(Icons.emoji_emotions),
                  onPressed: () {
                    setState(() {
                      _isEmojiVisible = !_isEmojiVisible;
                      if (_isEmojiVisible) {
                        FocusScope.of(context).unfocus();
                      }
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onTap: () {
                      if (_isEmojiVisible) {
                        setState(() {
                          _isEmojiVisible = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (BuildContext context) {
                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    ListTile(
                                      leading: Icon(Icons.camera_alt),
                                      title: Text('Camera'),
                                      onTap: () {
                                        Navigator.pop(
                                            context); // Close the bottom sheet
                                        print("Camera option selected");
                                        // Add your camera implementation here
                                      },
                                    ),
                                    ListTile(
                                      leading: Icon(Icons.photo_library),
                                      title: Text('Gallery'),
                                      onTap: () {
                                        Navigator.pop(
                                            context); // Close the bottom sheet
                                        print("Gallery option selected");
                                        // Add your gallery implementation here
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    if (_isSending) return;

    String message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
      _isEmojiVisible = false;
    });

    try {
      DocumentReference chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Add new message
      DocumentReference messageRef = chatRef.collection('messages').doc();
      batch.set(messageRef, {
        'text': message,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': currentUserId,
        'receiverId': widget.userId,
      });

      // Update chat document
      batch.set(
          chatRef,
          {
            'lastMessage': message,
            'timestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      await batch.commit();

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send message")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return "";
    return "${timestamp.hour % 12 == 0 ? '12' : (timestamp.hour % 12)}:"
        "${timestamp.minute.toString().padLeft(2, '0')} "
        "${timestamp.hour >= 12 ? 'PM' : 'AM'}";
  }

  String _formatDate(DateTime? timestamp) {
    if (timestamp == null) return "";

    bool isFirstDayOfYear = timestamp.month == 1 && timestamp.day == 1;

    if (isFirstDayOfYear) {
      return "${_getMonth(timestamp.month)} ${timestamp.day}, ${timestamp.year}";
    } else {
      return "${_getMonth(timestamp.month)} ${timestamp.day}, "
          "${timestamp.hour % 12 == 0 ? '12' : (timestamp.hour % 12)}:"
          "${timestamp.minute.toString().padLeft(2, '0')} "
          "${timestamp.hour >= 12 ? 'PM' : 'AM'}";
    }
  }

  String _getMonth(int month) {
    List<String> months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[month - 1];
  }
}
