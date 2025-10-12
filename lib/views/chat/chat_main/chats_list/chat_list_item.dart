import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:chatspot/views/chat/chat_main/image_handler.dart';
import 'package:chatspot/services/chat_cache_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatListItem extends StatefulWidget {
  final String userId;
  final String name;
  final String lastMessage;
  final DateTime? timestamp;
  final VoidCallback onTap;
  final String currentUserId;
  final String chatId;
  final bool isRead;

  const ChatListItem({
    required this.userId,
    required this.name,
    required this.lastMessage,
    this.timestamp,
    required this.onTap,
    required this.currentUserId,
    required this.chatId,
    required this.isRead,
  });

  @override
  _ChatListItemState createState() => _ChatListItemState();
}

class _ChatListItemState extends State<ChatListItem> {
  late bool _isRead;
  String? _profilePictureUrl;
  final ChatCacheService _chatCacheService = ChatCacheService();

  @override
  void initState() {
    super.initState();
    _isRead = widget.isRead;
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    try {
      // Check if the chat exists in the cache first
      final cachedChat = _chatCacheService.getChatByUserId(widget.userId);

      if (cachedChat != null && cachedChat.otherUserProfilePic != null) {
        if (mounted) {
          setState(() {
            _profilePictureUrl = cachedChat.otherUserProfilePic;
          });
        }
        return;
      }

      // Fallback to Firestore if not in cache
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _profilePictureUrl = data?['profilePictureUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error loading profile picture: $e");
    }
  }

  Future<void> _markAsRead() async {
    if (_isRead) return;

    try {
      // Try to update Firestore if permissions allow
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'readBy.${widget.currentUserId}': true,
      });

      // Also update in the cache for immediate UI feedback
      _chatCacheService.updateChatInCache(widget.chatId, isRead: true);
    } catch (e) {
      // If no permissions, we'll just update locally
      debugPrint("Couldn't update read status in Firestore: $e");
    }

    setState(() {
      _isRead = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _profilePictureUrl?.isNotEmpty == true
          ? GestureDetector(
              onTap: () {
                ImageHandler.showFullScreenImage(context, _profilePictureUrl!);
              },
              child: CircleAvatar(
                radius: 24,
                child: CachedNetworkImage(
                  imageUrl: _profilePictureUrl!,
                  imageBuilder: (context, imageProvider) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  placeholder: (context, url) => CircleAvatar(
                    child: Text(widget.name[0].toUpperCase()),
                    radius: 24,
                  ),
                  errorWidget: (context, url, error) => CircleAvatar(
                    child: Text(widget.name[0].toUpperCase()),
                    radius: 24,
                  ),
                  fadeInDuration: const Duration(milliseconds: 200),
                  fadeOutDuration: const Duration(milliseconds: 200),
                  memCacheHeight: 96,
                  memCacheWidth: 96,
                ),
              ),
            )
          : CircleAvatar(
              child: Text(widget.name[0].toUpperCase()),
              radius: 24,
            ),
      title: Text(
        widget.name,
        style: TextStyle(
          fontWeight: FontWeight.normal,
        ),
      ),
      subtitle: Text(
        widget.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.normal,
        ),
      ),
      trailing: Text(
        DateFormatters.formatMessageTime(widget.timestamp),
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.normal,
        ),
      ),
      onTap: () {
        _markAsRead();
        widget.onTap();
      },
    );
  }
}
