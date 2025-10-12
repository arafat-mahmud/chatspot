import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:chatspot/views/chat/chat_main/message_builders.dart';
import 'package:chatspot/views/chat/chat_main/message_services.dart';
import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:chatspot/services/message_cache_service.dart';
import 'package:chatspot/services/delete/message_context_menu.dart';
import 'package:chatspot/services/delete/message_selection_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatspot/views/chat/chat_main/image_handler.dart';

class ChatMessageList extends StatefulWidget {
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
  _ChatMessageListState createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final MessageCacheService _messageCacheService = MessageCacheService();
  List<DocumentSnapshot>? _cachedMessages;
  bool _isInSelectionMode = false;

  @override
  void initState() {
    super.initState();
    // Ensure we're listening to the message stream for this chat
    _messageCacheService.getMessageStream(widget.chatId);

    // Listen for selection mode changes
    MessageContextMenu.addSelectionListener(_onSelectionModeChanged);
  }

  @override
  void dispose() {
    // Remove selection listener
    MessageContextMenu.removeSelectionListener(_onSelectionModeChanged);
    super.dispose();
  }

  // Called when selection mode changes
  void _onSelectionModeChanged(bool isSelecting) {
    if (_isInSelectionMode != isSelecting) {
      setState(() {
        _isInSelectionMode = isSelecting;
      });
    }
  }

  /// Build a widget for displaying deleted messages
  Widget _buildDeletedMessage(
      BuildContext context, ThemeData theme, bool isUser, DateTime? timestamp) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.do_not_disturb,
                size: 16,
                color: theme.brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
              ),
              SizedBox(width: 6),
              Text(
                "This message was deleted",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 3),
          Text(
            DateFormatters.formatTimestamp(timestamp),
            style: TextStyle(
              fontSize: 10,
              color: theme.brightness == Brightness.dark
                  ? Colors.grey[400]?.withOpacity(0.7)
                  : Colors.grey[600]?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
        return Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  // If we have data in the snapshot, cache it
                  if (snapshot.hasData) {
                    _cachedMessages = snapshot.data!.docs;
                  }

                  // If we don't have data yet, check if we have cached messages
                  if (!snapshot.hasData && _cachedMessages != null) {
                    // Use cached messages while waiting for new data
                    return _buildMessageList(theme, _cachedMessages!);
                  }

                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  var messages = snapshot.data!.docs;
                  return _buildMessageList(theme, messages);
                },
              ),
            ),

            // WhatsApp-style action bar when in selection mode
            if (_isInSelectionMode)
              MessageSelectionActionBar(
                chatId: widget.chatId,
                theme: theme,
                selectedMessageText: _getSelectedMessageText(),
                isSelectedMessageImage: _isSelectedMessageImage(),
                onReply: () {
                  // Handle reply functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Reply feature not implemented yet")),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildMessageList(ThemeData theme, List<DocumentSnapshot> messages) {
    return ListView.builder(
      reverse: true,
      controller: widget.scrollController,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        var msg = messages[index].data() as Map<String, dynamic>;
        DateTime? timestamp = msg['timestamp']?.toDate();
        bool isUser = msg['senderId'] == widget.currentUserId;
        String messageText = msg['text'] ?? '';
        bool isImage = msg['isImage'] ?? false;
        bool isShortMessage = messageText.length <= 5;
        bool isDeleted = msg['isDeleted'] ?? false;
        var seenBy = msg['seenBy'] as Map<String, dynamic>? ?? {};
        bool hasSeen = seenBy.isNotEmpty;
        bool isSelected =
            MessageContextMenu.isMessageSelected(messages[index].id);

        // Mark message as seen if it's not sent by current user
        if (!isUser && !seenBy.containsKey(widget.currentUserId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            MessageServices.markMessageAsSeen(
              chatId: widget.chatId,
              messageId: messages[index].id,
              userId: widget.currentUserId,
            );
          });
        }

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

            // Determine if this message should show "seen by"
            bool shouldShowSeenBy = false;
            if (isUser && hasSeen) {
              // Find the most recent seen message by this user
              int mostRecentSeenIndex = -1;
              for (int i = 0; i < messages.length; i++) {
                var checkMsg = messages[i].data() as Map<String, dynamic>;
                var checkSeenBy =
                    checkMsg['seenBy'] as Map<String, dynamic>? ?? {};
                bool checkMsgSentByUser =
                    checkMsg['senderId'] == widget.currentUserId;

                if (checkMsgSentByUser && checkSeenBy.isNotEmpty) {
                  mostRecentSeenIndex = i;
                  break; // First one found is most recent (since list is reversed)
                }
              }

              // Show "seen by" only on the most recent seen message
              if (index == mostRecentSeenIndex) {
                shouldShowSeenBy = true;
              }
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
                          // WhatsApp-style selection checkbox on the left
                          if (_isInSelectionMode)
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 8, right: 8, bottom: 8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    MessageContextMenu.toggleMessageSelection(
                                        messages[index].id);
                                  });
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : Colors.grey,
                                      width: 2,
                                    ),
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          if (!isUser && !_isInSelectionMode)
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 8, right: 6.0, bottom: 0),
                              child: GestureDetector(
                                onTap: profilePictureUrl.isNotEmpty
                                    ? () {
                                        ImageHandler.showFullScreenImage(
                                            context, profilePictureUrl);
                                      }
                                    : null,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundImage: profilePictureUrl.isNotEmpty
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
                            ),
                          Stack(
                            children: [
                              if (isImage && !isDeleted)
                                GestureDetector(
                                  onTap: () {
                                    if (MessageContextMenu.isSelecting) {
                                      setState(() {
                                        MessageContextMenu
                                            .toggleMessageSelection(
                                                messages[index].id);
                                      });
                                    } else {
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
                                    }
                                  },
                                  onLongPress: () {
                                    MessageContextMenu.showMessageOptions(
                                      context: context,
                                      chatId: widget.chatId,
                                      messageId: messages[index].id,
                                      isUserMessage: isUser,
                                      isImage: true,
                                      messageText: '',
                                      theme: theme,
                                    );
                                  },
                                  child: MessageBuilders.buildImageMessage(
                                      context,
                                      msg['imageUrl'] ?? '',
                                      isUser,
                                      timestamp),
                                )
                              else
                                GestureDetector(
                                  onTap: () {
                                    if (MessageContextMenu.isSelecting) {
                                      setState(() {
                                        MessageContextMenu
                                            .toggleMessageSelection(
                                                messages[index].id);
                                      });
                                    }
                                  },
                                  onLongPress: () {
                                    if (!isDeleted) {
                                      MessageContextMenu.showMessageOptions(
                                        context: context,
                                        chatId: widget.chatId,
                                        messageId: messages[index].id,
                                        isUserMessage: isUser,
                                        isImage: false,
                                        messageText: messageText,
                                        theme: theme,
                                      );
                                    }
                                  },
                                  child: isDeleted
                                      ? _buildDeletedMessage(
                                          context, theme, isUser, timestamp)
                                      : MessageBuilders.buildTextMessage(
                                          context,
                                          messageText,
                                          isUser,
                                          timestamp,
                                          isShortMessage),
                                ),
                            ],
                          ),
                        ],
                      ),
                      // Show seen indicator based on the new logic
                      if (shouldShowSeenBy)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 8),
                          child: FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(msg['receiverId'])
                                .get(),
                            builder: (context, receiverSnapshot) {
                              if (receiverSnapshot.hasData) {
                                final receiverData = receiverSnapshot.data!
                                    .data() as Map<String, dynamic>?;
                                final receiverProfilePic =
                                    receiverData?['profilePictureUrl'] ?? '';
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
                                            ? Colors.grey[400] ?? Colors.grey
                                            : Colors.grey[600] ?? Colors.grey,
                                      ),
                                    ),
                                    if (receiverProfilePic.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          ImageHandler.showFullScreenImage(
                                              context, receiverProfilePic);
                                        },
                                        child: Container(
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
                                                ? receiverName[0].toUpperCase()
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
  }

  String? _getSelectedMessageText() {
    // Get text from the first selected message for copy functionality
    if (_cachedMessages == null) return null;

    final selectedIds = MessageContextMenu.getSelectedMessageIds();
    if (selectedIds.isEmpty) return null;

    for (var doc in _cachedMessages!) {
      if (selectedIds.contains(doc.id)) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['isImage'] != true) {
          return data['text'] as String?;
        }
      }
    }
    return null;
  }

  bool _isSelectedMessageImage() {
    // Check if any selected message is an image
    if (_cachedMessages == null) return false;

    final selectedIds = MessageContextMenu.getSelectedMessageIds();
    if (selectedIds.isEmpty) return false;

    for (var doc in _cachedMessages!) {
      if (selectedIds.contains(doc.id)) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['isImage'] == true) {
          return true;
        }
      }
    }
    return false;
  }
}
