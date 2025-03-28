// message_input.dart
import 'package:chatspot/views/chat/chat_main/image_handler.dart';
import 'package:chatspot/views/settings/theme.dart';
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController messageController;
  final ImageHandler imageHandler;
  final VoidCallback sendMessage;
  final bool isSending;

  const MessageInput({
    Key? key,
    required this.messageController,
    required this.imageHandler,
    required this.sendMessage,
    required this.isSending,
  }) : super(key: key);

  @override
  _MessageInputState createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool _isEmojiVisible = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
        return Column(
          children: [
            if (_isEmojiVisible)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    setState(() {
                      widget.messageController.text += emoji.emoji;
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
                      controller: widget.messageController,
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
                              color: theme.iconTheme.color?.withOpacity(0.6)),
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
                                            await widget.imageHandler
                                                .pickImage(ImageSource.camera);
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
                                            await widget.imageHandler
                                                .pickImage(ImageSource.gallery);
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
                      onSubmitted: (value) => widget.sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: widget.isSending ? null : widget.sendMessage,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
