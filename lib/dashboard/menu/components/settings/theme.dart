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

  // Light theme color scheme
  static const ColorScheme _lightColorScheme = ColorScheme.light(
    primary: Color(0xFF1976D2), // Blue for primary actions and focused states
    onPrimary: Colors.white,
    secondary: Color(0xFF0D47A1),
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black87,
    surfaceContainerHighest: Color(0xFFF5F5F5),
    onSurfaceVariant: Colors.black54,
    outline: Color(0xFF757575), // Darker grey for better visibility
    outlineVariant: Color(0xFFE0E0E0),
  );

  // Dark theme color scheme
  static const ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: Color(0xFF212121),
    onPrimary: Colors.white,
    secondary: Color(0xFF42A5F5),
    onSecondary: Colors.black,
    surface: Color(0xFF212121),
    onSurface: Color(0xFFE1E1E1),
    surfaceContainerHighest: Color(0xFF424242),
    onSurfaceVariant: Color(0xFFBDBDBD),
    outline: Color(0xFF757575),
    outlineVariant: Color(0xFF424242),
  );

  // Custom light theme - using comprehensive color scheme
  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _lightColorScheme,
    primaryColor:
        Colors.white, // Keep white for app bar and other primary elements
    scaffoldBackgroundColor: _lightColorScheme.surface,
    cardColor: _lightColorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: _lightColorScheme.surface,
      foregroundColor: _lightColorScheme.onSurface,
      iconTheme: IconThemeData(color: _lightColorScheme.onSurface),
      actionsIconTheme: IconThemeData(color: _lightColorScheme.onSurface),
      titleTextStyle: TextStyle(
        color: _lightColorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      elevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: IconThemeData(color: _lightColorScheme.onSurface),
    textTheme: TextTheme(
      displayLarge: TextStyle(color: _lightColorScheme.onSurface),
      displayMedium: TextStyle(color: _lightColorScheme.onSurface),
      displaySmall: TextStyle(color: _lightColorScheme.onSurface),
      headlineLarge: TextStyle(color: _lightColorScheme.onSurface),
      headlineMedium: TextStyle(color: _lightColorScheme.onSurface),
      headlineSmall: TextStyle(color: _lightColorScheme.onSurface),
      titleLarge: TextStyle(color: _lightColorScheme.onSurface),
      titleMedium: TextStyle(color: _lightColorScheme.onSurface),
      titleSmall: TextStyle(color: _lightColorScheme.onSurface),
      bodyLarge: TextStyle(color: _lightColorScheme.onSurface),
      bodyMedium: TextStyle(color: _lightColorScheme.onSurface),
      bodySmall: TextStyle(color: _lightColorScheme.onSurfaceVariant),
      labelLarge: TextStyle(color: _lightColorScheme.onSurface),
      labelMedium: TextStyle(color: _lightColorScheme.onSurface),
      labelSmall: TextStyle(color: _lightColorScheme.onSurfaceVariant),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightColorScheme.surface,
        foregroundColor: _lightColorScheme.onSurface,
        side: BorderSide(color: _lightColorScheme.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _lightColorScheme.outline, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _lightColorScheme.outline, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _lightColorScheme.primary, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _lightColorScheme.error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _lightColorScheme.error, width: 2.0),
      ),
      labelStyle: TextStyle(color: _lightColorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: _lightColorScheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: _lightColorScheme.primary),
      filled: false,
      fillColor: _lightColorScheme.surface,
    ),
    dividerColor: _lightColorScheme.outlineVariant,
  );

  // Custom dark theme - using comprehensive color scheme
  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _darkColorScheme,
    primaryColor: _darkColorScheme.primary,
    scaffoldBackgroundColor: _darkColorScheme.surface,
    cardColor: _darkColorScheme.surfaceContainerHighest,
    appBarTheme: AppBarTheme(
      backgroundColor: _darkColorScheme.surface,
      foregroundColor: _darkColorScheme.onSurface,
      iconTheme: IconThemeData(color: _darkColorScheme.onSurface),
      actionsIconTheme: IconThemeData(color: _darkColorScheme.onSurface),
      titleTextStyle: TextStyle(
        color: _darkColorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      elevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: IconThemeData(color: _darkColorScheme.onSurface),
    textTheme: TextTheme(
      displayLarge: TextStyle(color: _darkColorScheme.onSurface),
      displayMedium: TextStyle(color: _darkColorScheme.onSurface),
      displaySmall: TextStyle(color: _darkColorScheme.onSurface),
      headlineLarge: TextStyle(color: _darkColorScheme.onSurface),
      headlineMedium: TextStyle(color: _darkColorScheme.onSurface),
      headlineSmall: TextStyle(color: _darkColorScheme.onSurface),
      titleLarge: TextStyle(color: _darkColorScheme.onSurface),
      titleMedium: TextStyle(color: _darkColorScheme.onSurface),
      titleSmall: TextStyle(color: _darkColorScheme.onSurface),
      bodyLarge: TextStyle(color: _darkColorScheme.onSurface),
      bodyMedium: TextStyle(color: _darkColorScheme.onSurface),
      bodySmall: TextStyle(color: _darkColorScheme.onSurfaceVariant),
      labelLarge: TextStyle(color: _darkColorScheme.onSurface),
      labelMedium: TextStyle(color: _darkColorScheme.onSurface),
      labelSmall: TextStyle(color: _darkColorScheme.onSurfaceVariant),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkColorScheme.surfaceContainerHighest,
        foregroundColor: _darkColorScheme.onSurface,
        side: BorderSide(color: _darkColorScheme.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _darkColorScheme.outline, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _darkColorScheme.outline, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _darkColorScheme.secondary, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _darkColorScheme.error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: _darkColorScheme.error, width: 2.0),
      ),
      labelStyle: TextStyle(color: _darkColorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: _darkColorScheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: _darkColorScheme.secondary),
      filled: false,
      fillColor: _darkColorScheme.surface,
    ),
    dividerColor: _darkColorScheme.outlineVariant,
  );

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

  // Get theme-aware text colors for easy access
  static Color get primaryTextColor => _currentTheme.colorScheme.onSurface;
  static Color get secondaryTextColor =>
      _currentTheme.colorScheme.onSurfaceVariant;
  static Color get onPrimaryTextColor => _currentTheme.colorScheme.onPrimary;
  static Color get onSecondaryTextColor =>
      _currentTheme.colorScheme.onSecondary;

  // Get contrast text color for any background color
  static Color getContrastTextColor(Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  // Get adaptive text color based on current theme
  static Color getAdaptiveTextColor(BuildContext context,
      {double opacity = 1.0}) {
    return Theme.of(context).colorScheme.onSurface.withOpacity(opacity);
  }

  // Get adaptive secondary text color based on current theme
  static Color getAdaptiveSecondaryTextColor(BuildContext context,
      {double opacity = 0.6}) {
    return Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(opacity);
  }

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
      final userThemeKey =
          _currentUserId != null ? '${_themeKey}_$_currentUserId' : _themeKey;
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
      final userThemeKey =
          _currentUserId != null ? '${_themeKey}_$_currentUserId' : _themeKey;
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
