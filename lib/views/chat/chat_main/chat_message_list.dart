// chat_message_list.dart
import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:chatspot/views/chat/chat_main/message_builders.dart';
import 'package:chatspot/views/settings/theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageList extends StatelessWidget {
  final String currentUserId;
  final String chatId;
  final ScrollController scrollController;

  const ChatMessageList({
    Key? key,
    required this.currentUserId,
    required this.chatId,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
        return StreamBuilder<QuerySnapshot>(
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
              controller: scrollController,
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
                  var prevMsg =
                      messages[index + 1].data() as Map<String, dynamic>;
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
                            DateFormatters.formatDate(timestamp),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    if (isImage)
                      MessageBuilders.buildImageMessage(
                          context, msg['imageUrl'] ?? '', isUser, timestamp)
                    else
                      MessageBuilders.buildTextMessage(context, messageText,
                          isUser, timestamp, isShortMessage),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
