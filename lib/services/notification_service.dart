import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderId = 1001;
  static const int _dailyBudgetAlertId = 2001;
  static const int _monthlyBudgetAlertId = 2002;
  static const String _channelId = 'spend_smart_alerts';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  bool _initialized = false;

  Future<void> initialize({bool requestPermission = false}) async {
    if (!_initialized) {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      final darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: InitializationSettings(android: android, iOS: darwin, macOS: darwin),
        onDidReceiveNotificationResponse: (_) {},
      );
      _initialized = true;
    }

    if (requestPermission) await requestPermissions();
  }

  Future<bool?> requestPermissions() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final androidPermission = await android?.requestNotificationsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final iosPermission = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return androidPermission ?? iosPermission;
  }

  Future<bool?> areNotificationsEnabled() async {
    await initialize();
    return _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled();
  }

  Future<void> syncDailyReminder({required bool enabled, required TimeOfDay time}) async {
    await initialize();
    await _plugin.cancel(id: _dailyReminderId);
    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: 'Log today\'s spending',
      body: 'Take a minute to keep your Spend Smart history up to date.',
      scheduledDate: scheduled,
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_reminder',
    );
  }

  Future<void> showTestNotification() async {
    await initialize(requestPermission: true);
    await _plugin.show(
      id: 9001,
      title: 'Spend Smart is ready',
      body: 'Notifications are working perfectly on this device.',
      notificationDetails: _notificationDetails(),
      payload: 'test_notification',
    );
  }

  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    await initialize();
    return _plugin.pendingNotificationRequests();
  }

  Future<void> evaluateBudgetAlerts({required double todaySpent, required double monthSpent}) async {
    await initialize();
    final dailyEnabled = await _prefs.getBool('daily_limit_alert') ?? true;
    final monthlyEnabled = await _prefs.getBool('monthly_budget_alert') ?? true;
    final dailyLimit = await _prefs.getDouble('daily_limit') ?? 1000;
    final monthlyBudget = await _prefs.getDouble('monthly_budget') ?? 30000;
    final now = DateTime.now();

    if (dailyEnabled && dailyLimit > 0 && todaySpent >= dailyLimit) {
      final key = '${now.year}-${now.month}-${now.day}';
      final lastAlert = await _prefs.getString('daily_alert_sent');
      if (lastAlert != key) {
        await _plugin.show(
          id: _dailyBudgetAlertId,
          title: 'Daily limit reached',
          body: 'You have spent ৳${todaySpent.toStringAsFixed(0)} today.',
          notificationDetails: _notificationDetails(),
          payload: 'daily_limit',
        );
        await _prefs.setString('daily_alert_sent', key);
      }
    }

    if (monthlyEnabled && monthlyBudget > 0 && monthSpent >= monthlyBudget) {
      final key = '${now.year}-${now.month}';
      final lastAlert = await _prefs.getString('monthly_alert_sent');
      if (lastAlert != key) {
        await _plugin.show(
          id: _monthlyBudgetAlertId,
          title: 'Monthly budget reached',
          body: 'You have used ৳${monthSpent.toStringAsFixed(0)} of this month\'s budget.',
          notificationDetails: _notificationDetails(),
          payload: 'monthly_budget',
        );
        await _prefs.setString('monthly_alert_sent', key);
      }
    }
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Spend Smart alerts',
        channelDescription: 'Reminders and budget alerts from Spend Smart',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );
  }
}
