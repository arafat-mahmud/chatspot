import 'package:flutter/material.dart';

class DeleteMessageDialog {
  /// Shows options for deleting a message
  static Future<String?> showDeleteOptions({
    required BuildContext context,
    required bool isDarkMode,
    required int selectedCount,
  }) async {
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              'Delete ${selectedCount > 1 ? selectedCount : ""} Message${selectedCount > 1 ? "s" : ""}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.public_off, color: Colors.red),
                title: Text('Delete for everyone'),
                subtitle: Text('Delete for you and others in this chat'),
                onTap: () => Navigator.of(context).pop('everyone'),
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete for you'),
                subtitle:
                    Text('Other chat participants will still see this message'),
                onTap: () => Navigator.of(context).pop('you'),
              ),
              ListTile(
                leading: Icon(Icons.cancel_outlined,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                title: Text('Cancel'),
                onTap: () => Navigator.of(context).pop(null),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows a confirmation dialog for deleting all messages
  static Future<bool> showDeleteAllMessagesConfirmation({
    required BuildContext context,
    bool isDarkMode = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete All Messages'),
          content: Text(
              'Are you sure you want to delete all of your messages in this chat? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete All',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
