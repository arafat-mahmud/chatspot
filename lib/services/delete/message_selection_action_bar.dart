import 'package:flutter/material.dart';
import 'package:chatspot/services/delete/message_delete_service.dart';
import 'package:chatspot/services/delete/message_context_menu.dart';
import 'package:flutter/services.dart';

class MessageSelectionActionBar extends StatelessWidget {
  final String chatId;
  final ThemeData theme;
  final String? selectedMessageText;
  final bool isSelectedMessageImage;
  final VoidCallback onReply;

  const MessageSelectionActionBar({
    Key? key,
    required this.chatId,
    required this.theme,
    this.selectedMessageText,
    this.isSelectedMessageImage = false,
    required this.onReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final selectedCount = MessageContextMenu.selectedCount;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reply Button
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onReply,
                icon: Icon(
                  Icons.reply,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                splashRadius: 24,
              ),
              Text(
                'Reply',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),

          // Copy Button (only for text messages)
          if (!isSelectedMessageImage && selectedMessageText != null)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _copyText(context, selectedMessageText!),
                  icon: Icon(
                    Icons.copy,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  splashRadius: 24,
                ),
                Text(
                  'Copy',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

          // Delete Button
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => _showDeleteOptions(context, isDarkMode),
                    icon: Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 24,
                    ),
                    splashRadius: 24,
                  ),
                  if (selectedCount > 1)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints:
                            BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Center(
                          child: Text(
                            '$selectedCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                'Delete',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ],
          ),

          // More Button
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _showMoreOptions(context, isDarkMode),
                icon: Icon(
                  Icons.more_horiz,
                  color: theme.iconTheme.color,
                  size: 24,
                ),
                splashRadius: 24,
              ),
              Text(
                'More',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.iconTheme.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copyText(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    MessageContextMenu.clearSelections();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showDeleteOptions(BuildContext context, bool isDarkMode) async {
    final deleteService = MessageDeleteService();
    final selectedCount = MessageContextMenu.selectedCount;

    if (selectedCount == 0) return;

    // Get the selected message IDs
    final selectedMessageIds = MessageContextMenu.getSelectedMessageIds();

    // Show delete dialog
    final deleteOption = await _showDeleteDialog(context, selectedCount);

    if (deleteOption == null) return;

    if (deleteOption == 'everyone') {
      // Delete for everyone
      for (String id in selectedMessageIds) {
        try {
          await deleteService.deleteMessageForEveryone(
            chatId: chatId,
            messageId: id,
            context: context,
          );
        } catch (e) {
          print('Failed to delete message $id: $e');
        }
      }
    } else if (deleteOption == 'you') {
      // Delete for you
      for (String id in selectedMessageIds) {
        try {
          await deleteService.deleteMessage(
            chatId: chatId,
            messageId: id,
            context: context,
          );
        } catch (e) {
          print('Failed to delete message $id: $e');
        }
      }
    }

    MessageContextMenu.clearSelections();
  }

  Future<String?> _showDeleteDialog(BuildContext context, int count) async {
    final isDarkMode = theme.brightness == Brightness.dark;

    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Text(
                  'Delete message?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 20),

                // Delete for everyone option
                InkWell(
                  onTap: () => Navigator.of(context).pop('everyone'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Delete for everyone',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Delete for you option
                InkWell(
                  onTap: () => Navigator.of(context).pop('you'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Delete for you',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Cancel button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMoreOptions(BuildContext context, bool isDarkMode) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.push_pin),
                title: Text('Pin'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Pin feature not implemented yet")),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.forward),
                title: Text('Forward'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Forward feature not implemented yet")),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
