import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  ThemeMode _themeMode = ThemeMode.system;
  String _currency = 'BDT';
  String _userName = '';
  double _monthlyBudget = 30000;
  double _dailyLimit = 1000;
  bool _dailyLimitAlert = true;
  bool _monthlyBudgetAlert = true;
  bool _dailyReminder = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 20, minute: 0);

  bool _onboardingCompleted = false;
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;

  String get currency => _currency;

  String get userName => _userName;

  double get monthlyBudget => _monthlyBudget;

  double get dailyLimit => _dailyLimit;

  bool get dailyLimitAlert => _dailyLimitAlert;

  bool get monthlyBudgetAlert => _monthlyBudgetAlert;

  bool get dailyReminder => _dailyReminder;

  TimeOfDay get notificationTime => _notificationTime;

  bool get onboardingCompleted => _onboardingCompleted;

  bool get initialized => _initialized;

  Future<void> loadSettings() async {
    final savedTheme = await _prefs.getString('theme_mode');

    final savedCurrency = await _prefs.getString('currency');

    final savedOnboarding =
        await _prefs.getBool('onboarding_completed') ?? false;

    final savedUserName = await _prefs.getString('user_name');

    final savedMonthlyBudget = await _prefs.getDouble('monthly_budget');
    final savedDailyLimit = await _prefs.getDouble('daily_limit');
    final savedDailyAlert = await _prefs.getBool('daily_limit_alert');
    final savedMonthlyAlert = await _prefs.getBool('monthly_budget_alert');
    final savedDailyReminder = await _prefs.getBool('daily_reminder');
    final savedNotificationHour = await _prefs.getInt('notification_hour');
    final savedNotificationMinute = await _prefs.getInt('notification_minute');

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

    _userName = savedUserName ?? '';
    _monthlyBudget = savedMonthlyBudget ?? 30000;
    _dailyLimit = savedDailyLimit ?? 1000;
    _dailyLimitAlert = savedDailyAlert ?? true;
    _monthlyBudgetAlert = savedMonthlyAlert ?? true;
    _dailyReminder = savedDailyReminder ?? true;
    _notificationTime = TimeOfDay(
      hour: savedNotificationHour ?? 20,
      minute: savedNotificationMinute ?? 0,
    );

    _onboardingCompleted = savedOnboarding;

    _initialized = true;

    try {
      await NotificationService.instance.syncDailyReminder(
        enabled: _dailyReminder,
        time: _notificationTime,
      );
    } catch (_) {
      // Notification permission or platform setup should not block app startup.
    }

    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;

    await _prefs.setBool('onboarding_completed', true);

    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    await _prefs.setBool('onboarding_completed', false);
    _onboardingCompleted = false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
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

    await _prefs.setString('theme_mode', value);

    notifyListeners();
  }

  Future<void> setCurrency(String currency) async {
    _currency = currency;

    await _prefs.setString('currency', currency);

    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim();
    await _prefs.setString('user_name', _userName);
    notifyListeners();
  }

  Future<void> setMonthlyBudget(double amount) async {
    _monthlyBudget = amount;
    await _prefs.setDouble('monthly_budget', amount);
    notifyListeners();
  }

  Future<void> setDailyLimit(double amount) async {
    _dailyLimit = amount;
    await _prefs.setDouble('daily_limit', amount);
    notifyListeners();
  }

  Future<void> setBudgetLimits({required double monthlyBudget, required double dailyLimit}) async {
    _monthlyBudget = monthlyBudget;
    _dailyLimit = dailyLimit;
    await _prefs.setDouble('monthly_budget', monthlyBudget);
    await _prefs.setDouble('daily_limit', dailyLimit);
    notifyListeners();
  }

  Future<void> setDailyLimitAlert(bool enabled) async {
    _dailyLimitAlert = enabled;
    await _prefs.setBool('daily_limit_alert', enabled);
    notifyListeners();
  }

  Future<void> setMonthlyBudgetAlert(bool enabled) async {
    _monthlyBudgetAlert = enabled;
    await _prefs.setBool('monthly_budget_alert', enabled);
    notifyListeners();
  }

  Future<void> setDailyReminder(bool enabled) async {
    _dailyReminder = enabled;
    await _prefs.setBool('daily_reminder', enabled);
    await NotificationService.instance.syncDailyReminder(enabled: enabled, time: _notificationTime);
    notifyListeners();
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    _notificationTime = time;
    await _prefs.setInt('notification_hour', time.hour);
    await _prefs.setInt('notification_minute', time.minute);
    if (_dailyReminder) {
      await NotificationService.instance.syncDailyReminder(enabled: true, time: time);
    }
    notifyListeners();
  }
}
