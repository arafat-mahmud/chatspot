import 'package:flutter/material.dart';
import 'package:chatspot/dashboard/menu/components/settings/theme.dart';
import 'package:chatspot/dashboard/menu/components/settings/text_theme_helper.dart';

/// Example demonstrating proper usage of theme-aware text colors
/// This shows how to use the improved ThemeService and TextThemeHelper
class ThemeAwareTextExample extends StatelessWidget {
  const ThemeAwareTextExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Theme-Aware Text Demo',
          // Use theme-aware text color that adapts automatically
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              ThemeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              ThemeService.toggleTheme();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Using TextThemeHelper methods
            Text(
              'Primary Heading',
              style: TextThemeHelper.getHeadingTextStyle(context),
            ),
            SizedBox(height: 8),

            Text(
              'This is primary body text that adapts to light/dark mode automatically.',
              style: TextThemeHelper.getBodyTextStyle(context),
            ),
            SizedBox(height: 8),

            Text(
              'This is secondary text with lower opacity for subtitles.',
              style: TextThemeHelper.getSecondaryTextStyle(context),
            ),
            SizedBox(height: 16),

            // Using context extensions
            Text(
              'Using Context Extensions',
              style: context.headingTextStyle,
            ),
            SizedBox(height: 8),

            Text(
              'Body text using extension method.',
              style: context.bodyTextStyle,
            ),
            SizedBox(height: 8),

            Text(
              'Caption text using extension method.',
              style: context.captionTextStyle,
            ),
            SizedBox(height: 16),

            // Different text styles
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Card with Surface Text',
                    style: TextThemeHelper.getSurfaceTextStyle(
                      context,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This text adapts to the surface container background.',
                    style: TextThemeHelper.getSurfaceTextStyle(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Primary colored container
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Primary Container',
                    style: TextThemeHelper.getOnPrimaryTextStyle(
                      context,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Text on primary background with proper contrast.',
                    style: TextThemeHelper.getOnPrimaryTextStyle(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Status messages
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Messages',
                  style: TextThemeHelper.getHeadingTextStyle(context),
                ),
                SizedBox(height: 8),
                Text(
                  'Success message',
                  style: TextThemeHelper.getSuccessTextStyle(context),
                ),
                Text(
                  'Warning message',
                  style: TextThemeHelper.getWarningTextStyle(context),
                ),
                Text(
                  'Error message',
                  style: TextThemeHelper.getErrorTextStyle(context),
                ),
                Text(
                  'Disabled text',
                  style: TextThemeHelper.getDisabledTextStyle(context),
                ),
                Text(
                  'Link text',
                  style: TextThemeHelper.getLinkTextStyle(context),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Custom colored backgrounds
            Text(
              'Custom Background Contrasts',
              style: TextThemeHelper.getHeadingTextStyle(context),
            ),
            SizedBox(height: 8),

            // Red background
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'White text on red background',
                style:
                    TextThemeHelper.getContrastTextStyle(context, Colors.red),
              ),
            ),
            SizedBox(height: 8),

            // Light background
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Dark text on light background',
                style: TextThemeHelper.getContrastTextStyle(
                  context,
                  Colors.yellow.shade100,
                ),
              ),
            ),
            SizedBox(height: 16),

            // Direct theme access examples
            Text(
              'Direct Theme Access',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),

            Text(
              'Using Theme.of(context).colorScheme.onSurface',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            Text(
              'Using Theme.of(context).colorScheme.onSurfaceVariant',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            Text(
              'Using Theme.of(context).textTheme.bodyMedium',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show how to use ThemeService methods
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Current theme: ${ThemeService.isDarkMode ? 'Dark' : 'Light'}',
                style: TextThemeHelper.getContrastTextStyle(
                  context,
                  Theme.of(context).snackBarTheme.backgroundColor ??
                      Theme.of(context).colorScheme.inverseSurface,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.inverseSurface,
            ),
          );
        },
        child: Icon(Icons.info_outline),
      ),
    );
  }
}

/// Widget showing chat bubble examples with proper theming
class ChatBubbleExample extends StatelessWidget {
  const ChatBubbleExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // User message
        _buildChatBubble(
          context,
          'Hello! This is a user message with proper theme-aware colors.',
          isUser: true,
        ),
        SizedBox(height: 8),

        // Other person message
        _buildChatBubble(
          context,
          'This is a response message that adapts to dark/light mode.',
          isUser: false,
        ),
      ],
    );
  }

  Widget _buildChatBubble(BuildContext context, String message,
      {required bool isUser}) {
    final theme = Theme.of(context);
    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: isUser ? Radius.circular(16) : Radius.circular(4),
            bottomRight: isUser ? Radius.circular(4) : Radius.circular(16),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }
}
