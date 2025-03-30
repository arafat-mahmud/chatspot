import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeService {
  static const String _themeKey = 'app_theme';
  static ThemeData _currentTheme = _lightTheme;
  static bool _isDarkMode = false;
  static String? _currentUserId;
  static ValueNotifier<ThemeData> themeNotifier = ValueNotifier(_lightTheme);

  // Custom light theme
  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
    // Add other light theme properties
  ));

  // Custom dark theme (ensuring good contrast)
  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.blue[700],
    scaffoldBackgroundColor: Colors.grey[900],
    cardColor: Colors.grey[800],
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.white.withOpacity(0.9)),
    // Add other dark theme properties
  ));

  // Initialize theme service
  static Future<void> init() async {
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    await _loadTheme();
  }

  // Update current user when auth state changes
  static void updateCurrentUser(String? userId) {
    _currentUserId = userId;
    _loadTheme();
  }

  // Get current theme
  static ThemeData get currentTheme => _currentTheme;

  // Check if dark mode is enabled
  static bool get isDarkMode => _isDarkMode;

  // Change theme
  static Future<void> changeTheme(ThemeData theme) async {
    _currentTheme = theme;
    _isDarkMode = theme.brightness == Brightness.dark;
    themeNotifier.value = theme;
    final themeName = _getNameFromTheme(theme);
    await _saveTheme(themeName);
  }

  // Toggle between light/dark theme
  static Future<void> toggleTheme() async {
    if (_isDarkMode) {
      await changeTheme(_lightTheme);
    } else {
      await changeTheme(_darkTheme);
    }
  }

  // Private helper methods
  static Future<void> _loadTheme() async {
    try {
      final themeName = await _getStoredThemeName();
      final newTheme = themeName == 'dark' ? _darkTheme : _lightTheme;
      _currentTheme = newTheme;
      _isDarkMode = newTheme.brightness == Brightness.dark;
      themeNotifier.value = newTheme;
    } catch (e) {
      print('Error loading theme: $e');
      _currentTheme = _lightTheme;
      _isDarkMode = false;
      themeNotifier.value = _lightTheme;
    }
  }

  static Future<String?> _getStoredThemeName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userThemeKey = _currentUserId != null ? '${_themeKey}_$_currentUserId' : _themeKey;
      final localTheme = prefs.getString(userThemeKey);
      if (localTheme != null) return localTheme;

      if (_currentUserId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .get();
        return doc.data()?['theme'] as String?;
      }
    } catch (e) {
      print('Error getting stored theme: $e');
    }
    return null;
  }

  static Future<void> _saveTheme(String themeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userThemeKey = _currentUserId != null ? '${_themeKey}_$_currentUserId' : _themeKey;
      await prefs.setString(userThemeKey, themeName);

      if (_currentUserId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .set({'theme': themeName}, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  static String _getNameFromTheme(ThemeData theme) {
    return theme.brightness == Brightness.dark ? 'dark' : 'light';
  }
}