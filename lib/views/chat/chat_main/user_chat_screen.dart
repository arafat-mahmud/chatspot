import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:chatspot/views/chat/chat_main/message_builders.dart';
import 'package:chatspot/views/chat/chat_main/message_services.dart';
import 'package:chatspot/views/chat/chat_main/image_handler.dart';
import 'package:chatspot/views/settings/theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';

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
  late ImageHandler _imageHandler;

  String get currentUserId => FirebaseAuth.instance.currentUser!.uid;

  String get chatId {
    List<String> ids = [currentUserId, widget.userId];
    ids.sort();
    return ids.join("-");
  }

  @override
  void initState() {
    super.initState();
    _imageHandler = ImageHandler(
      context: context,
      chatId: chatId,
      currentUserId: currentUserId,
      receiverId: widget.userId,
      scrollToBottom: _scrollToBottom,
      setLoadingState: (isLoading) {
        if (mounted) {
          setState(() {
            _isSending = isLoading;
          });
        }
      },
    );
    _scrollController.addListener(_scrollListener);
    ThemeService.init();
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

  void _sendMessage() async {
    if (_isSending) return;

    String message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
      _isEmojiVisible = false;
    });

    try {
      await MessageServices.sendTextMessage(
        chatId: chatId,
        currentUserId: currentUserId,
        receiverId: widget.userId,
        message: message,
        context: context,
      );

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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
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
          body: Container(
            color: theme.scaffoldBackgroundColor,
            child: Column(
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
                          var msg =
                              messages[index].data() as Map<String, dynamic>;
                          DateTime? timestamp = msg['timestamp']?.toDate();
                          bool isUser = msg['senderId'] == currentUserId;
                          String messageText = msg['text'] ?? '';
                          bool isImage = msg['isImage'] ?? false;
                          bool isShortMessage = messageText.length <= 5;

                          bool showDateHeader = false;

                          if (index == messages.length - 1) {
                            showDateHeader = true;
                          } else {
                            var prevMsg = messages[index + 1].data()
                                as Map<String, dynamic>;
                            DateTime? prevTimestamp =
                                prevMsg['timestamp']?.toDate();

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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Center(
                                    child: Text(
                                      DateFormatters.formatDate(timestamp),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? Colors.grey[400]
                                                : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ),
                              if (isImage)
                                MessageBuilders.buildImageMessage(context,
                                    msg['imageUrl'] ?? '', isUser, timestamp)
                              else
                                MessageBuilders.buildTextMessage(
                                    context,
                                    messageText,
                                    isUser,
                                    timestamp,
                                    isShortMessage),
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
                              icon: Icon(Icons.attach_file,
                                  color:
                                      theme.iconTheme.color?.withOpacity(0.6)),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return Container(
                                      color: theme.cardColor,
                                      child: SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            ListTile(
                                              leading: Icon(Icons.camera_alt,
                                                  color: theme.iconTheme.color),
                                              title: Text('Camera',
                                                  style: TextStyle(
                                                      color: theme.textTheme
                                                          .bodyLarge?.color)),
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await _imageHandler.pickImage(
                                                    ImageSource.camera);
                                              },
                                            ),
                                            ListTile(
                                              leading: Icon(Icons.photo_library,
                                                  color: theme.iconTheme.color),
                                              title: Text('Gallery',
                                                  style: TextStyle(
                                                      color: theme.textTheme
                                                          .bodyLarge?.color)),
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await _imageHandler.pickImage(
                                                    ImageSource.gallery);
                                              },
                                            ),
                                          ],
                                        ),
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
                            fillColor: theme.brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[200],
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
          ),
        );
      },
    );
  }
}
