import 'package:chatspot/views/chat/chat_main/chat_message_list.dart';
import 'package:chatspot/views/chat/chat_main/message_services.dart';
import 'package:chatspot/views/chat/chat_main/image_handler.dart';
import 'package:chatspot/views/chat/chat_main/message_input.dart';
import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    // Listener logic remains the same
  }

  void _sendMessage() async {
    if (_isSending) return;

    String message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
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
                  child: ChatMessageList(
                    currentUserId: currentUserId,
                    chatId: chatId,
                    scrollController: _scrollController,
                  ),
                ),
                MessageInput(
                  messageController: _messageController,
                  imageHandler: _imageHandler,
                  sendMessage: _sendMessage,
                  isSending: _isSending,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}