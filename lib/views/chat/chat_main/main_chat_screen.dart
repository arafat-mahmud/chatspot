import 'dart:async';

import 'package:chatspot/views/chat/chat_main/chat_message_list.dart';
import 'package:chatspot/views/chat/chat_main/image_handler.dart';
import 'package:chatspot/views/chat/chat_main/message_input.dart';
import 'package:chatspot/views/chat/chat_main/user_profile_screen.dart';
import 'package:chatspot/views/chat/chat_main/chat_app_bar.dart';
import 'package:chatspot/views/common/presence_widgets.dart';
import 'package:chatspot/services/app_messenger.dart';
import 'package:chatspot/services/call/call_model.dart';
import 'package:chatspot/services/call/call_service.dart';
import 'package:chatspot/services/chat/chat_models.dart';
import 'package:chatspot/services/chat/chat_repository.dart';
import 'package:chatspot/services/chat/chat_room_controller.dart';
import 'package:chatspot/services/friend/friend_models.dart';
import 'package:chatspot/services/friend/friend_repository.dart';
import 'package:chatspot/services/notification/push_notification_service.dart';
import 'package:chatspot/services/user/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserChatScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserChatScreen({super.key, required this.userId, required this.userName});

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _chats = ChatRepository.instance;
  late final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  late final String chatId = chatIdFor(currentUserId, widget.userId);
  late final ChatRoomController _room = ChatRoomController(chatId)..start();
  late final ImageHandler _imageHandler;
  bool _uploading = false;
  Timer? _markReadTimer;

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
        if (mounted) setState(() => _uploading = isLoading);
      },
    );
    WidgetsBinding.instance.addObserver(this);
    // Every new incoming message bumps the chat's unread count.
    _chats.chats.addListener(_scheduleMarkRead);
    _scheduleMarkRead();
    // No notifications for this chat while it's on screen.
    PushNotificationService.instance.activeChatUserId = widget.userId;
    PushNotificationService.instance.clearChat(chatId);
  }

  @override
  void dispose() {
    final push = PushNotificationService.instance;
    if (push.activeChatUserId == widget.userId) push.activeChatUserId = null;
    WidgetsBinding.instance.removeObserver(this);
    _chats.chats.removeListener(_scheduleMarkRead);
    _markReadTimer?.cancel();
    _room.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleMarkRead();
  }

  /// Debounced so a burst of messages costs one write, and only while the
  /// chat is actually visible.
  void _scheduleMarkRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final visible = WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed &&
          (ModalRoute.of(context)?.isCurrent ?? false);
      if (visible) _chats.markRead(chatId);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    // Clear at once: the message appears immediately and syncs in the
    // background, even offline.
    _messageController.clear();
    final sent = await _chats.sendText(widget.userId, text);
    if (!sent) {
      _messageController.text = text;
      AppMessenger.error('You can only message friends');
      return;
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _startCall(CallType type, String name, String photoUrl) {
    CallService.instance.startCall(
      context,
      calleeId: widget.userId,
      calleeName: name,
      calleePhotoUrl: photoUrl,
      type: type,
    );
  }

  void _openUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<FriendsState>(
      valueListenable: FriendRepository.instance.state,
      builder: (context, friends, _) {
        final friend = friends.friend(widget.userId);
        final cached = UserRepository.instance.peek(widget.userId);
        final name = friend?.displayName ?? cached?.displayName ?? widget.userName;
        final photoUrl = friend?.photoUrl ?? cached?.photoUrl ?? '';
        // Until the friends list arrives, assume the chat is allowed.
        final canChat = !friends.loaded || friend != null;

        return Scaffold(
          appBar: ChatAppBar(
            titleSpacing: 0,
            title: name,
            titleWidget: InkWell(
              onTap: _openUserProfile,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    PresenceAvatar(
                      uid: widget.userId,
                      name: name,
                      photoUrl: photoUrl,
                      radius: 18,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          PresenceLabel(
                            uid: widget.userId,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (canChat) ...[
                IconButton(
                  icon: const Icon(Icons.videocam_outlined),
                  tooltip: 'Video call',
                  onPressed: () => _startCall(CallType.video, name, photoUrl),
                ),
                IconButton(
                  icon: const Icon(Icons.call_outlined),
                  tooltip: 'Voice call',
                  onPressed: () => _startCall(CallType.audio, name, photoUrl),
                ),
              ],
            ],
          ),
          body: Container(
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                Expanded(
                  child: ValueListenableBuilder<List<ChatSummary>>(
                    valueListenable: _chats.chats,
                    builder: (context, _, __) => ChatMessageList(
                      room: _room,
                      currentUserId: currentUserId,
                      chatId: chatId,
                      peerName: name,
                      peerPhotoUrl: photoUrl,
                      peerLastRead: _chats.summary(chatId)?.peerLastRead,
                      scrollController: _scrollController,
                    ),
                  ),
                ),
                if (canChat)
                  MessageInput(
                    messageController: _messageController,
                    imageHandler: _imageHandler,
                    sendMessage: _sendMessage,
                    isSending: _uploading,
                  )
                else
                  _NotFriendsBanner(name: name),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotFriendsBanner extends StatelessWidget {
  const _NotFriendsBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: scheme.surfaceContainerHighest,
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You're no longer friends with $name. Add them again to chat.",
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
