import 'package:flutter/material.dart';

// This class provides a global way to remove back buttons from AppBars
class NoBackButtonAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Widget? titleWidget;
  final double? titleSpacing;
  final Color? titleColor;
  final IconThemeData? iconTheme;

  const NoBackButtonAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.titleWidget,
    this.titleSpacing,
    this.titleColor,
    this.iconTheme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      automaticallyImplyLeading:
          false, // This is the key - it removes the back button
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
      titleSpacing: titleSpacing,
      iconTheme: iconTheme ?? theme.appBarTheme.iconTheme,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
