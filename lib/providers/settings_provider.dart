import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferencesAsync _prefs =
      SharedPreferencesAsync();

  ThemeMode _themeMode = ThemeMode.system;
  String _currency = 'BDT';

  bool _onboardingCompleted = false;
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;

  String get currency => _currency;

  bool get onboardingCompleted =>
      _onboardingCompleted;

  bool get initialized => _initialized;

  Future<void> loadSettings() async {
    final savedTheme =
        await _prefs.getString('theme_mode');

    final savedCurrency =
        await _prefs.getString('currency');

    final savedOnboarding =
        await _prefs.getBool(
              'onboarding_completed',
            ) ??
            false;

    switch (savedTheme) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;

      case 'dark':
        _themeMode = ThemeMode.dark;
        break;

      default:
        _themeMode = ThemeMode.system;
    }

    _currency = savedCurrency ?? 'BDT';

    _onboardingCompleted =
        savedOnboarding;

    _initialized = true;

    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;

    await _prefs.setBool(
      'onboarding_completed',
      true,
    );

    notifyListeners();
  }

  Future<void> setThemeMode(
    ThemeMode mode,
  ) async {
    _themeMode = mode;

    String value;

    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;

      case ThemeMode.dark:
        value = 'dark';
        break;

      case ThemeMode.system:
        value = 'system';
        break;
    }

    await _prefs.setString(
      'theme_mode',
      value,
    );

    notifyListeners();
  }

  Future<void> setCurrency(
    String currency,
  ) async {
    _currency = currency;

    await _prefs.setString(
      'currency',
      currency,
    );

    notifyListeners();
  }
}