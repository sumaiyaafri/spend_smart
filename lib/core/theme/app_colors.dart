import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF078B67);
  static const primaryDark = Color(0xFF04684E);

  static const background = Color(0xFFF7FAF9);
  static const surface = Colors.white;

  static const softGreen = Color(0xFFE4F7F0);

  static const textPrimary = Color(0xFF18252E);
  static const textSecondary = Color(0xFF74828C);

  static const border = Color(0xFFE8EEEE);

  static const orange = Color(0xFFFFA558);
  static const blue = Color(0xFF5C9EFF);
  static const red = Color(0xFFFF6B6B);
  static const purple = Color(0xFF8B72F6);
}

extension SpendSmartThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get pageBackground => Theme.of(this).scaffoldBackgroundColor;

  Color get surfaceColor => Theme.of(this).colorScheme.surface;

  Color get fieldColor => Theme.of(this).inputDecorationTheme.fillColor ?? surfaceColor;

  Color get primaryTextColor => Theme.of(this).colorScheme.onSurface;

  Color get secondaryTextColor => Theme.of(this).colorScheme.onSurfaceVariant;

  Color get outlineColor => Theme.of(this).colorScheme.outline;

  Color get mutedSurfaceColor => isDarkMode ? const Color(0xFF102B28) : const Color(0xFFF0F5F3);

  Color get softGreenColor => isDarkMode ? const Color(0xFF123C34) : AppColors.softGreen;
}
