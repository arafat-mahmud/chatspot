import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatspot/views/chat/chat_main/image_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatListItem extends StatelessWidget {
  final String userId;
  final String name;
  final String lastMessage;
  final DateTime? timestamp;
  final VoidCallback onTap;

  const ChatListItem({
    required this.userId,
    required this.name,
    required this.lastMessage,
    this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final profilePictureUrl = data?['profilePictureUrl'] as String?;

          if (profilePictureUrl?.isNotEmpty == true) {
            return GestureDetector(
              onTap: () {
                ImageHandler.showFullScreenImage(context, profilePictureUrl);
              },
              child: CircleAvatar(
                radius: 24,
                child: CachedNetworkImage(
                  imageUrl: profilePictureUrl!,
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
                    child: Text(name[0].toUpperCase()),
                    radius: 24,
                  ),
                  errorWidget: (context, url, error) => CircleAvatar(
                    child: Text(name[0].toUpperCase()),
                    radius: 24,
                  ),
                  fadeInDuration: const Duration(milliseconds: 200),
                  fadeOutDuration: const Duration(milliseconds: 200),
                  memCacheHeight: 96,
                  memCacheWidth: 96,
                ),
              ),
            );
          }

          return CircleAvatar(
            child: Text(name[0].toUpperCase()),
            radius: 24,
          );
        },
      ),
      title: Text(name),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatMessageTime(timestamp),
        style: const TextStyle(color: Colors.grey),
      ),
      onTap: onTap,
    );
  }

  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}