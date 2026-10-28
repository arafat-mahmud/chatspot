import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:chatspot/views/chat/chat_main/image_handler.dart';
import 'package:chatspot/views/chat/chat_main/main_chat_screen.dart';
import 'package:chatspot/views/common/state_views.dart';
import 'package:chatspot/views/common/presence_widgets.dart';
import 'package:chatspot/services/chat/chat_models.dart';
import 'package:chatspot/services/delete/conversation_delete_service.dart';
import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One chat in the list. Everything it shows is already in [chat]; it never
/// reads from Firestore.
class ChatListItem extends StatelessWidget {
  const ChatListItem({super.key, required this.chat});

  final ChatSummary chat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = chat.hasUnread;
    final fromMe =
        chat.lastSenderId == FirebaseAuth.instance.currentUser?.uid;
    final preview = chat.lastMessage.isEmpty
        ? 'Say hi 👋'
        : (fromMe ? 'You: ${chat.lastMessage}' : chat.lastMessage);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: PresenceAvatar(
        uid: chat.peerId,
        name: chat.peerName,
        photoUrl: chat.peerPhotoUrl,
        onTap: chat.peerPhotoUrl.isEmpty
            ? null
            : () => ImageHandler.showFullScreenImage(
                context, chat.peerPhotoUrl),
      ),
      title: Text(
        chat.peerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
          fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormatters.formatMessageTime(chat.lastMessageTime),
            style: theme.textTheme.bodySmall?.copyWith(
              color: unread ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 6),
          if (unread) CountBadge(chat.unreadCount) else const SizedBox(height: 18),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              UserChatScreen(userId: chat.peerId, userName: chat.peerName),
        ),
      ),
      onLongPress: () => _confirmDelete(context),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final shouldDelete =
        await ConversationDeleteService.showDeleteConversationDialog(
      context: context,
      otherUserName: chat.peerName,
      theme: ThemeService.themeNotifier.value,
    );
    if (shouldDelete != true || !context.mounted) return;
    await ConversationDeleteService.deleteConversation(
      chatId: chat.chatId,
      otherUserId: chat.peerId,
      otherUserName: chat.peerName,
      context: context,
    );
  }
}
