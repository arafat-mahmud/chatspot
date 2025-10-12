import 'package:flutter/material.dart';

// This class provides an AppBar with a back button specifically for chat screens
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Widget? titleWidget;
  final double? titleSpacing;
  final Color? titleColor;
  final IconThemeData? iconTheme;
  final VoidCallback? onBackPressed;

  const ChatAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.titleWidget,
    this.titleSpacing,
    this.titleColor,
    this.iconTheme,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      // Include back button
      automaticallyImplyLeading: true,
      // Customize back button behavior if needed
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      ),
      title: titleWidget ??
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: titleColor ??
                  (theme.appBarTheme.titleTextStyle?.color ?? Colors.white),
            ),
          ),
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor ?? theme.primaryColor,
      titleSpacing: titleSpacing ?? NavigationToolbar.kMiddleSpacing,
      iconTheme: iconTheme ?? theme.appBarTheme.iconTheme,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
