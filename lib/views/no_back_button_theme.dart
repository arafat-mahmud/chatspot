import 'package:flutter/material.dart';

class NoBackButtonTheme {
  // Creates a custom AppBar without a back button
  static PreferredSizeWidget appBarWithoutBackButton({
    required BuildContext context,
    required String title,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
    Widget? titleWidget,
    double? titleSpacing,
    Color? backgroundColor,
    Color? titleColor,
    IconThemeData? iconTheme,
  }) {
    return AppBar(
      automaticallyImplyLeading: false, // This removes the back button
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
      title: titleWidget ??
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.bold,
            ),
          ),
      titleSpacing: titleSpacing,
      actions: actions,
      bottom: bottom,
      iconTheme: iconTheme,
    );
  }
}
