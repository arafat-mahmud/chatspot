import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; // Ensure this import is correct

class UserChatScreen extends StatefulWidget {
  final String userName;

  UserChatScreen({Key? key, required this.userName}) : super(key: key);

  @override
  _UserChatScreenState createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isEmojiVisible = false; // Track the visibility of the emoji picker
  List<Map<String, dynamic>> _messages =
      []; // List to store chat messages and timestamps

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
            child: ListView.builder(
              itemCount: _messages.length, // Count of messages
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.symmetric(
                      vertical: 4.0,
                      horizontal: 8.0), // Margin around each message
                  padding: EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 6.0), // Adjust padding to be dynamic
                  decoration: BoxDecoration(
                    color: Colors.blue[100], // Background color for the message
                    borderRadius:
                        BorderRadius.circular(30.0), // Rounded corners
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // Align text to the start
                    children: [
                      Text(
                        _formatTimestamp(_messages[index][
                            'timestamp']), // Display timestamp above the message
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey), // Style for timestamp
                      ),
                      SizedBox(
                          height: 4), // Space between timestamp and message
                      Text(
                        _messages[index]
                            ['text'], // Display each message without background
                        style: TextStyle(color: Colors.black), // Text color
                      ),
                    ],
                  ),
                );
              },
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
                            _isEmojiVisible =
                                !_isEmojiVisible; // Toggle emoji picker visibility
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
      setState(() {
        _messages.add({
          'text': message, // Store the message text
          'timestamp': DateTime.now(), // Store the current timestamp
        });
      });
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

  String _formatTimestamp(DateTime timestamp) {
    String hour = timestamp.hour % 12 == 0
        ? '12'
        : (timestamp.hour % 12).toString(); // Convert to 12-hour format
    String minute = timestamp.minute
        .toString()
        .padLeft(2, '0'); // Ensure two digits for minutes
    String period = timestamp.hour >= 12 ? 'PM' : 'AM'; // Determine AM/PM
    return "$hour:$minute $period"; // Format timestamp
  }
}
