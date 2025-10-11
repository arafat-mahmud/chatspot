import 'package:flutter/material.dart';

/// Utility class for creating consistent text field decorations
/// that work properly with both light and dark themes
class TextFieldDecorationHelper {
  /// Get theme-aware input decoration for text fields
  static InputDecoration getInputDecoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
    Widget? suffixIcon,
    Widget? prefixIcon,
    String? errorText,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      errorText: errorText,
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,

      // Default border (enabled but not focused)
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          color: colorScheme.outline,
          width: 1.0,
        ),
      ),

      // Enabled border (when field is enabled but not focused)
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          color: colorScheme.outline,
          width: 1.0,
        ),
      ),

      // Focused border (when field is focused/active)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 2.0,
        ),
      ),

      // Error border (when there's an error but field is not focused)
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 1.0,
        ),
      ),

      // Focused error border (when there's an error and field is focused)
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 2.0,
        ),
      ),

      // Disabled border (when field is disabled)
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(
          color: colorScheme.outline.withOpacity(0.38),
          width: 1.0,
        ),
      ),

      // Text styles
      labelStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontFamily: 'Chivo',
      ),
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
        fontFamily: 'Chivo',
      ),
      floatingLabelStyle: TextStyle(
        color: colorScheme.primary,
        fontFamily: 'Chivo',
      ),
      errorStyle: TextStyle(
        color: colorScheme.error,
        fontFamily: 'Chivo',
      ),

      // Fill colors
      filled: false,
      fillColor: colorScheme.surface,

      // Content padding
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  /// Get theme-aware text style for text fields
  static TextStyle getTextFieldTextStyle(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.onSurface,
      fontFamily: 'Chivo',
      fontSize: 16,
    );
  }

  /// Get theme-aware password field decoration
  static InputDecoration getPasswordFieldDecoration(
    BuildContext context, {
    required String labelText,
    required bool isPasswordVisible,
    required VoidCallback onToggleVisibility,
    String? errorText,
  }) {
    return getInputDecoration(
      context,
      labelText: labelText,
      errorText: errorText,
      suffixIcon: IconButton(
        icon: Icon(
          isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: onToggleVisibility,
      ),
    );
  }

  /// Get theme-aware dropdown decoration
  static InputDecoration getDropdownDecoration(
    BuildContext context, {
    required String labelText,
    String? errorText,
  }) {
    return getInputDecoration(
      context,
      labelText: labelText,
      errorText: errorText,
    );
  }

  /// Get theme-aware date picker decoration
  static InputDecoration getDatePickerDecoration(
    BuildContext context, {
    required String labelText,
    String? errorText,
  }) {
    return getInputDecoration(
      context,
      labelText: labelText,
      errorText: errorText,
      suffixIcon: Icon(
        Icons.calendar_today,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Extension to make it easier to use
extension TextFieldDecorationExtension on BuildContext {
  /// Get input decoration with theme awareness
  InputDecoration getInputDecoration(
    String labelText, {
    String? hintText,
    Widget? suffixIcon,
    Widget? prefixIcon,
    String? errorText,
    bool readOnly = false,
  }) {
    return TextFieldDecorationHelper.getInputDecoration(
      this,
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      errorText: errorText,
      readOnly: readOnly,
    );
  }

  /// Get text field text style
  TextStyle get textFieldTextStyle =>
      TextFieldDecorationHelper.getTextFieldTextStyle(this);
}
