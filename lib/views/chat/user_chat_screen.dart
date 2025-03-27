import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatspot/services/cloudinary_service.dart';


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
  final ImagePicker _picker = ImagePicker();

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
                    var msg = messages[index].data() as Map<String, dynamic>;
                    DateTime? timestamp = msg['timestamp']?.toDate();
                    bool isUser = msg['senderId'] == currentUserId;
                    String messageText = msg['text'] ?? '';
                    bool isImage = msg['isImage'] ?? false;
                    bool isShortMessage = messageText.length <= 5;

                    bool showDateHeader = false;

                    if (index == messages.length - 1) {
                      showDateHeader = true;
                    } else {
                      var prevMsg = messages[index + 1].data() as Map<String, dynamic>;
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
                        if (isImage)
                          _buildImageMessage(msg['imageUrl'] ?? '', isUser, timestamp)
                        else
                          _buildTextMessage(messageText, isUser, timestamp, isShortMessage),
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
            onTap: () async {
              Navigator.pop(context);
              final image = await _picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
              );
              if (image != null) {
                await _uploadAndSendImage(image.path, source: ImageSource.camera);
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Gallery'),
            onTap: () async {
              Navigator.pop(context);
              final image = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (image != null) {
                await _uploadAndSendImage(image.path, source: ImageSource.gallery);
              }
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

  Widget _buildTextMessage(String message, bool isUser, DateTime? timestamp, bool isShortMessage) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: isUser ? Color.fromARGB(231, 11, 69, 244) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: isUser ? Radius.circular(20) : Radius.circular(0),
            bottomRight: isUser ? Radius.circular(22) : Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
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
                    message,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser ? Colors.white.withOpacity(0.8) : Colors.grey[700],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser ? Colors.white.withOpacity(0.8) : Colors.grey[700],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImageMessage(String imageUrl, bool isUser, DateTime? timestamp) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
          maxHeight: 300,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAndSendImage(String imagePath, {required ImageSource source}) async {
    try {
      setState(() {
        _isSending = true;
      });

      // Show loading indicator
      final loadingSnackBar = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Uploading image...'),
            ],
          ),
          duration: Duration(minutes: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Upload to the correct folder based on source
      final cloudinaryService = CloudinaryService();
      final imageUrl = source == ImageSource.camera
          ? await cloudinaryService.uploadCameraPicture(imagePath)  // Goes to chatspot_camera_pictures
          : await cloudinaryService.uploadGalleryPicture(imagePath); // Goes to chatspot_gallery_pictures

      // Hide loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Create message object
      final imageMessage = {
        'text': '',
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': currentUserId,
        'receiverId': widget.userId,
        'isImage': true,
        'source': source == ImageSource.camera ? 'camera' : 'gallery',
      };

      // Send to Firestore
      await _sendImageMessage(imageMessage);
      
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Image upload error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendImageMessage(Map<String, dynamic> message) async {
    try {
      DocumentReference chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Add new message
      DocumentReference messageRef = chatRef.collection('messages').doc();
      batch.set(messageRef, {
        'text': message['text'] ?? '',
        'imageUrl': message['imageUrl'],
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': currentUserId,
        'receiverId': widget.userId,
        'isImage': true,
      });

      // Update chat document
      batch.set(
          chatRef,
          {
            'lastMessage': '[Photo]',
            'lastMessageTime': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      await batch.commit();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending image message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image')),
      );
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
        'isImage': false,
      });

      // Update chat document
      batch.set(
          chatRef,
          {
            'lastMessage': message,
            'lastMessageTime': FieldValue.serverTimestamp(),
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
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[month - 1];
  }
}