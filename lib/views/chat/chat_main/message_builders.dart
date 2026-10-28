import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:chatspot/dashboard/menu/components/settings/text_theme_helper.dart';
import 'package:flutter/material.dart';

class MessageBuilders {
  static Widget buildTextMessage(BuildContext context, String message,
      bool isUser, DateTime? timestamp, bool isShortMessage) {
    final theme = Theme.of(context);

    // Use theme-aware colors for message bubbles
    final userBubbleColor = theme.colorScheme.primary;
    final otherBubbleColor = theme.colorScheme.surfaceContainerHighest;

    // Get appropriate text colors based on bubble background
    final userTextColor = TextThemeHelper.getContrastTextColor(userBubbleColor);
    final otherTextColor = theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: isUser ? userBubbleColor : otherBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: isUser ? Radius.circular(20) : Radius.circular(0),
            bottomRight: isUser ? Radius.circular(22) : Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: isShortMessage
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isUser ? userTextColor : otherTextColor,
                        fontSize: theme.textTheme.bodyMedium?.fontSize,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    DateFormatters.formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? userTextColor.withOpacity(0.8)
                          : otherTextColor.withOpacity(0.6),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isUser ? userTextColor : otherTextColor,
                        fontSize: theme.textTheme.bodyMedium?.fontSize,
                      ),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    DateFormatters.formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? userTextColor.withOpacity(0.8)
                          : otherTextColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static Widget buildImageMessage(
      BuildContext context, String imageUrl, bool isUser, DateTime? timestamp) {
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
          maxHeight: 300,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              // Cached on disk and decoded at bubble size, so scrolling
              // back never downloads a photo again.
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: (MediaQuery.sizeOf(context).width *
                        0.75 *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
                placeholder: (context, url) => Container(
                  height: 200,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  DateFormatters.formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
