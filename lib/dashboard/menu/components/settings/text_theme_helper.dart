import 'package:flutter/material.dart';

/// A comprehensive helper class for theme-aware text styling
/// This ensures consistent text colors across light and dark modes
class TextThemeHelper {
  /// Get the primary text style for body content
  static TextStyle getBodyTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.onSurface.withOpacity(opacity),
      fontSize: fontSize ?? theme.textTheme.bodyMedium?.fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get secondary text style (for subtitles, descriptions)
  static TextStyle getSecondaryTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 0.7,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.onSurfaceVariant.withOpacity(opacity),
      fontSize: fontSize ?? theme.textTheme.bodySmall?.fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get heading text style
  static TextStyle getHeadingTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.onSurface.withOpacity(opacity),
      fontSize: fontSize ?? theme.textTheme.titleLarge?.fontSize,
      fontWeight: fontWeight ?? FontWeight.bold,
    );
  }

  /// Get text style for text on primary color backgrounds
  static TextStyle getOnPrimaryTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.onPrimary.withOpacity(opacity),
      fontSize: fontSize ?? theme.textTheme.bodyMedium?.fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get text style for text on surface containers (cards, dialogs)
  static TextStyle getSurfaceTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.onSurface.withOpacity(opacity),
      fontSize: fontSize ?? theme.textTheme.bodyMedium?.fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get error text style
  static TextStyle getErrorTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.error.withOpacity(opacity),
      fontSize: fontSize ?? theme.textTheme.bodySmall?.fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get success text style (using primary color)
  static TextStyle getSuccessTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: Colors.green.shade600.withOpacity(opacity),
      fontSize: fontSize ?? theme.textTheme.bodySmall?.fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get warning text style
  static TextStyle getWarningTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: Colors.orange.shade600.withOpacity(opacity),
      fontSize: fontSize ?? theme.textTheme.bodySmall?.fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get text style with custom color that adapts to theme
  static TextStyle getCustomTextStyle(
    BuildContext context,
    Color color, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: color.withOpacity(opacity),
      fontSize: fontSize ?? theme.textTheme.bodyMedium?.fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get appropriate text color for any background color
  static Color getContrastTextColor(Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  /// Get text style for any background color (ensures good contrast)
  static TextStyle getContrastTextStyle(
    BuildContext context,
    Color backgroundColor, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 1.0,
  }) {
    final theme = Theme.of(context);
    final textColor = getContrastTextColor(backgroundColor);
    return TextStyle(
      color: textColor.withOpacity(opacity),
      fontSize: fontSize ?? theme.textTheme.bodyMedium?.fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get disabled text style
  static TextStyle getDisabledTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.disabledColor,
      fontSize: fontSize ?? theme.textTheme.bodyMedium?.fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Get link text style
  static TextStyle getLinkTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    bool underline = true,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.primary,
      fontSize: fontSize ?? theme.textTheme.bodyMedium?.fontSize,
      fontWeight: fontWeight,
      decoration: underline ? TextDecoration.underline : null,
    );
  }

  /// Get caption text style (small text like timestamps)
  static TextStyle getCaptionTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    double opacity = 0.6,
  }) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.onSurfaceVariant.withOpacity(opacity),
      fontSize: fontSize ?? (theme.textTheme.bodySmall?.fontSize ?? 12) - 1,
      fontWeight: fontWeight,
    );
  }
}

/// Extension on BuildContext for easy access to theme-aware text styles
extension TextThemeExtension on BuildContext {
  /// Get theme-aware body text style
  TextStyle get bodyTextStyle => TextThemeHelper.getBodyTextStyle(this);

  /// Get theme-aware secondary text style
  TextStyle get secondaryTextStyle =>
      TextThemeHelper.getSecondaryTextStyle(this);

  /// Get theme-aware heading text style
  TextStyle get headingTextStyle => TextThemeHelper.getHeadingTextStyle(this);

  /// Get theme-aware caption text style
  TextStyle get captionTextStyle => TextThemeHelper.getCaptionTextStyle(this);

  /// Get theme-aware on-primary text style
  TextStyle get onPrimaryTextStyle =>
      TextThemeHelper.getOnPrimaryTextStyle(this);
}
