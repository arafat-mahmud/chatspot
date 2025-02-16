import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class UserChatScreen extends StatefulWidget {
  final String userName;

  UserChatScreen({Key? key, required this.userName}) : super(key: key);

  @override
  _UserChatScreenState createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isEmojiVisible = false;
  List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

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
          Divider(),
          Expanded(
            child: ListView.builder(
              reverse: true,
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUser = _isUserMessage(index);
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                    decoration: BoxDecoration(
                      color: isUser ? const Color.fromARGB(231, 11, 167, 244) : const Color.fromARGB(255, 255, 255, 255),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _messages[index]['text'],
                          style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255)),
                        ),
                        SizedBox(height: 1), //timestamp and message spacing
                        Text(
                          _formatTimestamp(_messages[index]['timestamp']),
                          style: TextStyle(fontSize:10, color: Colors.grey[700]),
                        ),
                         
                        
                      ],
                    ),
                  ),
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
                        _isEmojiVisible = false; // Close emoji picker when tapping the input field
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
                      suffixIcon: IconButton(
                        icon: Icon(Icons.attach_file),
                        onPressed: () {
                          _showFileOptions(context);
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

  void _sendMessage() {
    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      setState(() {
        _messages.insert(0, {
          'text': message,
          'timestamp': DateTime.now(),
          'isUser': true,
        });
      });
      _messageController.clear();
      _scrollToBottom();
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

  void _showFileOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 200,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.photo),
                title: Text('Gallery'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(Icons.camera),
                title: Text('Camera'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isUserMessage(int index) {
    return _messages[index]['isUser'] ?? true;
  }

  String _formatTimestamp(DateTime timestamp) {
    String hour = timestamp.hour % 12 == 0 ? '12' : (timestamp.hour % 12).toString();
    String minute = timestamp.minute.toString().padLeft(2, '0');
    String period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }
}
