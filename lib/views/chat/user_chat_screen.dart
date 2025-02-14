import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; // Ensure this import is correct

class UserChatScreen extends StatefulWidget {
  final String userName;

  UserChatScreen({required this.userName});

  @override
  _UserChatScreenState createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isEmojiVisible = false; // Track the visibility of the emoji picker

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        actions: [
          IconButton(
            icon: Icon(Icons.video_call),
            onPressed: () {
              // Handle video call
            },
          ),
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () {
              // Handle audio call
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Divider(),
          Expanded(
            child: ListView(
                // This will contain the chat messages
                ),
          ),
          if (_isEmojiVisible) // Show emoji picker if visible
            SizedBox(
              height: 250, // Adjust height as needed
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  setState(() {
                    _messageController.text +=
                        emoji.emoji; // Append selected emoji to the message
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
                      _isEmojiVisible =
                          !_isEmojiVisible; // Toggle emoji picker visibility
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
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
                  onPressed: () {
                    _sendMessage();
                  },
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
      // Handle sending the message (e.g., add to chat list, send to server)
      print("Message sent: $message"); // Replace with actual send logic
      _messageController.clear(); // Clear the input field after sending
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
                onTap: () {
                  // Handle gallery option
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera),
                title: Text('Camera'),
                onTap: () {
                  // Handle camera option
                  Navigator.pop(context);
                },
              ),
              // Add more options if needed
            ],
          ),
        );
      },
    );
  }
}
