import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:chatspot/views/chat/chat_main/message_builders.dart';
import 'package:chatspot/views/chat/chat_main/message_services.dart';
import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatspot/views/chat/chat_main/image_handler.dart';

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
                var seenBy = msg['seenBy'] as Map<String, dynamic>? ?? {};
                bool hasSeen = seenBy.isNotEmpty;
                bool isLastMessage = index == 0; // First item in reverse list

                // Mark message as seen if it's not sent by current user
                if (!isUser && !seenBy.containsKey(currentUserId)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    MessageServices.markMessageAsSeen(
                      chatId: chatId,
                      messageId: messages[index].id,
                      userId: currentUserId,
                    );
                  });
                }

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

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(msg['senderId'])
                      .snapshots(),
                  builder: (context, userSnapshot) {
                    String profilePictureUrl = '';
                    String senderName = '';

                    if (userSnapshot.hasData) {
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>?;
                      profilePictureUrl = userData?['profilePictureUrl'] ?? '';
                      senderName = userData?['name'] ?? '';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Center(
                              child: Text(
                                DateFormatters.formatDate(timestamp),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.grey[400] ?? Colors.grey
                                      : Colors.grey[700] ?? Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          margin: EdgeInsets.only(bottom: 0, top: 0),
                          child: Column(
                            crossAxisAlignment: isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: isUser
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  if (!isUser)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8, right: 6.0, bottom: 0),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundImage:
                                            profilePictureUrl.isNotEmpty
                                                ? CachedNetworkImageProvider(
                                                    profilePictureUrl)
                                                : null,
                                        child: profilePictureUrl.isEmpty
                                            ? Text(senderName.isNotEmpty
                                                ? senderName[0].toUpperCase()
                                                : '')
                                            : null,
                                      ),
                                    ),
                                  if (isImage)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FullScreenImageView(
                                              imageUrl: msg['imageUrl'] ?? '',
                                              timestamp: timestamp,
                                              isUser: isUser,
                                            ),
                                          ),
                                        );
                                      },
                                      child: MessageBuilders.buildImageMessage(
                                          context,
                                          msg['imageUrl'] ?? '',
                                          isUser,
                                          timestamp),
                                    )
                                  else
                                    MessageBuilders.buildTextMessage(
                                        context,
                                        messageText,
                                        isUser,
                                        timestamp,
                                        isShortMessage),
                                ],
                              ),
                              // Only show seen indicator on last message
                              if (isLastMessage && isUser && hasSeen)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 2, right: 8),
                                  child: FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(msg['senderId'])
                                        .get(),
                                    builder: (context, receiverSnapshot) {
                                      if (receiverSnapshot.hasData) {
                                        final receiverData =
                                            receiverSnapshot.data!.data()
                                                as Map<String, dynamic>?;
                                        final receiverProfilePic =
                                            receiverData?[
                                                    'profilePictureUrl'] ??
                                                '';
                                        final receiverName =
                                            receiverData?['name'] ?? '';

                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Seen by ',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: theme.brightness ==
                                                        Brightness.dark
                                                    ? Colors.grey[400] ??
                                                        Colors.grey
                                                    : Colors.grey[600] ??
                                                        Colors.grey,
                                              ),
                                            ),
                                            if (receiverProfilePic.isNotEmpty)
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                        receiverProfilePic),
                                                    fit: BoxFit.cover,
                                                  ),
                                                  border: Border.all(
                                                    color: theme.brightness ==
                                                            Brightness.dark
                                                        ? Colors.grey[400] ??
                                                            Colors.grey
                                                        : Colors.grey[200] ??
                                                            Colors.grey,
                                                    width: 1,
                                                  ),
                                                ),
                                              )
                                            else
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.grey,
                                                  border: Border.all(
                                                    color: theme.brightness ==
                                                            Brightness.dark
                                                        ? Colors.grey[400] ??
                                                            Colors.grey
                                                        : Colors.grey[200] ??
                                                            Colors.grey,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    receiverName.isNotEmpty
                                                        ? receiverName[0]
                                                            .toUpperCase()
                                                        : msg['receiverId'][0]
                                                            .toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 6,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      }
                                      return SizedBox.shrink();
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
