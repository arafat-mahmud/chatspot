import 'package:chatspot/views/chat/chat_main/date_formatters.dart';
import 'package:flutter/material.dart';

class MessageBuilders {
  static Widget buildTextMessage(BuildContext context, String message,
      bool isUser, DateTime? timestamp, bool isShortMessage) {
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: isUser
              ? theme.primaryColor
              : theme.brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: isUser ? Radius.circular(20) : Radius.circular(0),
            bottomRight: isUser ? Radius.circular(22) : Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
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
                  Text(
                    message,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    DateFormatters.formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? Colors.white.withOpacity(0.8)
                          : theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    DateFormatters.formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? Colors.white.withOpacity(0.8)
                          : theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
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
              color: Colors.grey.withOpacity(0.2),
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
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: theme.cardColor,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: theme.cardColor,
                    child: Center(
                      child: Icon(Icons.broken_image,
                          color: theme.iconTheme.color),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  DateFormatters.formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
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