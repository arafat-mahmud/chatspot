import 'package:flutter/material.dart';

/// Shows snackbars from anywhere, including from writes that finish (or
/// fail) after the screen that started them is gone.
class AppMessenger {
  AppMessenger._();

  /// Attached to [MaterialApp.scaffoldMessengerKey].
  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static void show(String message) => _show(message, null);

  static void error(String message) =>
      _show(message, Colors.red.shade700);

  static void _show(String message, Color? background) {
    key.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ));
  }
}
