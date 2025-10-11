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

  const NoBackButtonAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.titleWidget,
    this.titleSpacing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading:
          false, // This is the key - it removes the back button
      title: titleWidget ?? Text(title),
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor,
      titleSpacing: titleSpacing,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
