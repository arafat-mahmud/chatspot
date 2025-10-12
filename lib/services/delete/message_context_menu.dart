import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatspot/services/delete/message_delete_service.dart';
import 'package:chatspot/services/delete/delete_message_dialog.dart';

class MessageContextMenu {
  // Keep track of selected messages
  static Map<String, bool> _selectedMessages = {};
  static int get selectedCount =>
      _selectedMessages.entries.where((e) => e.value).length;
  static bool isSelecting = false;

  // Selection mode listeners
  static final List<Function(bool)> _selectionListeners = [];

  // Register a callback for selection mode changes
  static void addSelectionListener(Function(bool) listener) {
    _selectionListeners.add(listener);
  }

  // Remove a selection listener
  static void removeSelectionListener(Function(bool) listener) {
    _selectionListeners.remove(listener);
  }

  // Notify all listeners of selection mode change
  static void _notifySelectionListeners() {
    for (var listener in _selectionListeners) {
      listener(isSelecting);
    }
  }

  // Clear all selections
  static void clearSelections() {
    _selectedMessages.clear();
    isSelecting = false;
    _notifySelectionListeners();
  }

  // Toggle selection for a message
  static bool toggleMessageSelection(String messageId) {
    if (!_selectedMessages.containsKey(messageId)) {
      _selectedMessages[messageId] = true;
    } else {
      _selectedMessages[messageId] = !_selectedMessages[messageId]!;
    }

    isSelecting = selectedCount > 0;
    _notifySelectionListeners();
    return _selectedMessages[messageId]!;
  }

  // Check if a message is selected
  static bool isMessageSelected(String messageId) {
    return _selectedMessages[messageId] ?? false;
  }

  // Get selected message IDs
  static List<String> getSelectedMessageIds() {
    return _selectedMessages.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  // Start selection mode with a message already selected
  static void startSelectionMode(String messageId) {
    _selectedMessages[messageId] = true;
    isSelecting = true;
    _notifySelectionListeners();
  }

  /// Public method to show delete options for selected messages
  static Future<void> showDeleteSelectedMessages(
    BuildContext context,
    String chatId,
    bool isDarkMode,
  ) async {
    await _showDeleteSelectedMessages(context, chatId, isDarkMode);
  }

  /// Show a bottom sheet with message options or start selection mode
  static Future<void> showMessageOptions({
    required BuildContext context,
    required String chatId,
    required String messageId,
    required bool isUserMessage,
    required bool isImage,
    required String messageText,
    required ThemeData theme,
  }) async {
    // For user messages, start selection mode directly (WhatsApp style)
    if (isUserMessage) {
      startSelectionMode(messageId);
      return;
    }

    // For other user messages, show limited options
    final isDarkMode = theme.brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header handle for drag
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Copy option for text messages
                if (!isImage)
                  ListTile(
                    leading: Icon(Icons.copy, color: theme.iconTheme.color),
                    title: Text('Copy'),
                    onTap: () async {
                      await _copyTextToClipboard(context, messageText);
                      Navigator.pop(context);
                    },
                  ),

                // Reply option
                ListTile(
                  leading: Icon(Icons.reply, color: theme.iconTheme.color),
                  title: Text('Reply'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Reply feature not implemented yet")),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show additional options in another bottom sheet
  // ignore: unused_element
  static Future<void> _showMoreOptions(
    BuildContext context,
    ThemeData theme,
    String messageId,
    String chatId,
    bool isUserMessage,
  ) async {
    final isDarkMode = theme.brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header handle for drag
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Pin Message
                ListTile(
                  leading: Icon(Icons.push_pin, color: theme.iconTheme.color),
                  title: Text('Pin'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Pin feature not implemented yet")),
                    );
                  },
                ),

                // Forward Message
                ListTile(
                  leading: Icon(Icons.forward, color: theme.iconTheme.color),
                  title: Text('Forward'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Forward feature not implemented yet")),
                    );
                  },
                ),

                // Bump Message
                ListTile(
                  leading:
                      Icon(Icons.arrow_upward, color: theme.iconTheme.color),
                  title: Text('Bump'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Bump feature not implemented yet")),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Copy text to clipboard
  static Future<void> _copyTextToClipboard(
      BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Show options to delete selected messages
  static Future<void> _showDeleteSelectedMessages(
    BuildContext context,
    String chatId,
    bool isDarkMode,
  ) async {
    final deleteService = MessageDeleteService();
    final count = selectedCount;

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No messages selected')),
      );
      return;
    }

    // Get the selected message IDs
    final selectedMessageIds = _selectedMessages.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // Show delete options dialog
    final deleteOption = await DeleteMessageDialog.showDeleteOptions(
      context: context,
      isDarkMode: isDarkMode,
      selectedCount: count,
    );

    if (deleteOption == null) {
      return; // User cancelled
    }

    // Show deletion in progress indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleting ${count} message${count > 1 ? 's' : ''}...'),
        duration: Duration(seconds: 2),
      ),
    );

    if (deleteOption == 'everyone') {
      // Delete for everyone - replace with "message was deleted"
      bool anyFailed = false;
      for (String id in selectedMessageIds) {
        try {
          await deleteService.deleteMessageForEveryone(
            chatId: chatId,
            messageId: id,
            context: context,
          );
        } catch (e) {
          print('Failed to delete message $id: $e');
          anyFailed = true;
        }
      }

      // Show result message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(anyFailed
              ? 'Some messages could not be deleted'
              : 'Messages deleted for everyone'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (deleteOption == 'you') {
      // Delete only for current user - remove from database
      bool anyFailed = false;
      for (String id in selectedMessageIds) {
        try {
          await deleteService.deleteMessage(
            chatId: chatId,
            messageId: id,
            context: context,
          );
        } catch (e) {
          print('Failed to delete message $id: $e');
          anyFailed = true;
        }
      }

      // Show result message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(anyFailed
              ? 'Some messages could not be deleted'
              : 'Messages deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Clear selections after action
    clearSelections();
  }
}
