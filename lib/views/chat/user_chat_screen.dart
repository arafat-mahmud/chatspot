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
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUser = _isUserMessage(index);
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[300] : Colors.grey[300],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: isUser ? Radius.circular(18) : Radius.circular(0),
                        bottomRight: isUser ? Radius.circular(0) : Radius.circular(18),
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatTimestamp(_messages[index]['timestamp']),
                          style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _messages[index]['text'],
                          style: TextStyle(color: Colors.black),
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
        _messages.add({
          'text': message,
          'timestamp': DateTime.now(),
          'isUser': true,
        });
      });
      _messageController.clear();
    }
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
