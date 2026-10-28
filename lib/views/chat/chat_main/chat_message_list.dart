import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:chatspot/views/chat/chat_main/message_builders.dart';
import 'package:chatspot/views/common/state_views.dart';
import 'package:chatspot/views/common/user_avatar.dart';
import 'package:chatspot/services/chat/chat_models.dart';
import 'package:chatspot/services/chat/chat_room_controller.dart';
import 'package:chatspot/services/delete/message_context_menu.dart';
import 'package:chatspot/services/delete/message_selection_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:chatspot/views/chat/chat_main/image_handler.dart';

/// The messages of one chat, newest at the bottom.
///
/// Renders [room]'s in-memory messages only: no per-message listeners or
/// profile reads. Scrolling up loads older pages.
class ChatMessageList extends StatefulWidget {
  final ChatRoomController room;
  final String currentUserId;
  final String chatId;
  final String peerName;
  final String peerPhotoUrl;

  /// When the peer last read this chat; drives the "Seen" receipt.
  final DateTime? peerLastRead;
  final ScrollController scrollController;

  const ChatMessageList({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.chatId,
    required this.peerName,
    required this.peerPhotoUrl,
    required this.peerLastRead,
    required this.scrollController,
  });

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  bool _isInSelectionMode = false;

  @override
  void initState() {
    super.initState();
    MessageContextMenu.addSelectionListener(_onSelectionModeChanged);
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    MessageContextMenu.removeSelectionListener(_onSelectionModeChanged);
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onSelectionModeChanged(bool isSelecting) {
    if (_isInSelectionMode != isSelecting) {
      setState(() => _isInSelectionMode = isSelecting);
    }
  }

  /// The list is reversed: "after" is towards older messages.
  void _onScroll() {
    final position = widget.scrollController.position;
    if (position.extentAfter < 400) widget.room.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: widget.room,
            builder: (context, _) {
              final room = widget.room;
              final messages = room.messages;
              if (messages.isEmpty && !room.loaded) {
                return const Center(child: CircularProgressIndicator());
              }
              if (messages.isEmpty) {
                return EmptyState(
                  icon: Icons.waving_hand_outlined,
                  title: 'Say hi to ${widget.peerName}',
                  message: 'Messages you send appear here.',
                );
              }
              return _buildMessageList(theme, messages, room);
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Reply feature not implemented yet")),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMessageList(
    ThemeData theme,
    List<ChatMessage> messages,
    ChatRoomController room,
  ) {
    // Status shows under our newest message only.
    final newestOwn =
        messages.indexWhere((m) => m.senderId == widget.currentUserId);
    final showLoader = room.loadingMore || room.hasMore;

    return ListView.builder(
      reverse: true,
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + (showLoader ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final message = messages[index];
        final older = index + 1 < messages.length ? messages[index + 1] : null;
        final newer = index > 0 ? messages[index - 1] : null;
        final isUser = message.senderId == widget.currentUserId;
        final showDateHeader = older == null ||
            !_sameDay(message.timestamp, older.timestamp);
        // The peer's avatar sits next to the last message of each run.
        final lastOfRun = newer == null || newer.senderId != message.senderId;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDateHeader) _buildDateHeader(theme, message.timestamp),
            _buildMessageRow(theme, message, isUser, lastOfRun),
            if (index == newestOwn) _buildStatus(theme, message),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(ThemeData theme, DateTime? timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormatters.formatDate(timestamp),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageRow(
    ThemeData theme,
    ChatMessage message,
    bool isUser,
    bool lastOfRun,
  ) {
    final isSelected = MessageContextMenu.isMessageSelected(message.id);

    void toggleSelection() {
      setState(() => MessageContextMenu.toggleMessageSelection(message.id));
    }

    final Widget bubble;
    if (message.isImage && !message.isDeleted) {
      bubble = GestureDetector(
        onTap: () {
          if (MessageContextMenu.isSelecting) {
            toggleSelection();
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenImageView(
                imageUrl: message.imageUrl,
                timestamp: message.timestamp,
                isUser: isUser,
              ),
            ),
          );
        },
        onLongPress: () => MessageContextMenu.showMessageOptions(
          context: context,
          chatId: widget.chatId,
          messageId: message.id,
          isUserMessage: isUser,
          isImage: true,
          messageText: '',
          theme: theme,
        ),
        child: MessageBuilders.buildImageMessage(
            context, message.imageUrl, isUser, message.timestamp),
      );
    } else {
      bubble = GestureDetector(
        onTap: () {
          if (MessageContextMenu.isSelecting) toggleSelection();
        },
        onLongPress: message.isDeleted
            ? null
            : () => MessageContextMenu.showMessageOptions(
                  context: context,
                  chatId: widget.chatId,
                  messageId: message.id,
                  isUserMessage: isUser,
                  isImage: false,
                  messageText: message.text,
                  theme: theme,
                ),
        child: message.isDeleted
            ? _buildDeletedMessage(theme, isUser, message.timestamp)
            : MessageBuilders.buildTextMessage(context, message.text, isUser,
                message.timestamp, message.text.length <= 5),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (_isInSelectionMode)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: GestureDetector(
              onTap: toggleSelection,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected ? theme.colorScheme.primary : Colors.grey,
                    width: 2,
                  ),
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
        if (!isUser && !_isInSelectionMode)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 2, bottom: 4),
            child: lastOfRun
                ? UserAvatar(
                    name: widget.peerName,
                    photoUrl: widget.peerPhotoUrl,
                    radius: 14,
                  )
                : const SizedBox(width: 28),
          ),
        Flexible(child: bubble),
      ],
    );
  }

  /// "Sending…", "Sent" or "Seen" under our newest message.
  Widget _buildStatus(ThemeData theme, ChatMessage message) {
    final seenAt = widget.peerLastRead;
    final time = message.timestamp;
    final String label;
    final IconData icon;
    if (message.pending) {
      label = 'Sending';
      icon = Icons.schedule;
    } else if (seenAt != null && time != null && !time.isAfter(seenAt)) {
      label = 'Seen';
      icon = Icons.done_all;
    } else {
      label = 'Sent';
      icon = Icons.done;
    }
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 14, top: 2, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildDeletedMessage(
      ThemeData theme, bool isUser, DateTime? timestamp) {
    final color = theme.colorScheme.onSurfaceVariant;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.do_not_disturb, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                "This message was deleted",
                style: TextStyle(
                    fontStyle: FontStyle.italic, color: color, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormatters.formatTimestamp(timestamp),
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String? _getSelectedMessageText() {
    final selectedIds = MessageContextMenu.getSelectedMessageIds();
    for (final message in widget.room.messages) {
      if (selectedIds.contains(message.id) && !message.isImage) {
        return message.text;
      }
    }
    return null;
  }

  bool _isSelectedMessageImage() {
    final selectedIds = MessageContextMenu.getSelectedMessageIds();
    return widget.room.messages
        .any((m) => selectedIds.contains(m.id) && m.isImage);
  }
}
