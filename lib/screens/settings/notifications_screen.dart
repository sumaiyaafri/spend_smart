import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  bool _permissionGranted = true;
  bool _dailyScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    final settings = context.read<SettingsProvider>();
    final service = NotificationService.instance;
    await service.initialize(requestPermission: true);
    if (settings.dailyReminder) {
      await service.syncDailyReminder(enabled: true, time: settings.notificationTime);
    }
    final permission = await service.areNotificationsEnabled();
    final pending = await service.pendingNotifications();
    if (!mounted) return;
    setState(() {
      _permissionGranted = permission ?? true;
      _dailyScheduled = pending.any((item) => item.id == 1001);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final expenses = context.watch<ExpenseProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _topBar(),
            const SizedBox(height: 8),
            _heroCard(settings),
            const SizedBox(height: 16),
            _sectionTitle('Daily reminder'),
            const SizedBox(height: 7),
            _card([
              _switchRow(
                icon: Icons.notifications_active_rounded,
                color: AppColors.primary,
                title: 'Spending reminder',
                subtitle: 'Get a gentle reminder to log today\'s spending',
                value: settings.dailyReminder,
                onChanged: _toggleDailyReminder,
              ),
              _divider(),
              _tapRow(
                icon: Icons.schedule_rounded,
                color: AppColors.blue,
                title: 'Reminder time',
                subtitle: _formatTime(settings.notificationTime),
                onTap: settings.dailyReminder ? () => _pickTime(settings) : null,
              ),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('Budget alerts'),
            const SizedBox(height: 7),
            _card([
              _switchRow(
                icon: Icons.speed_rounded,
                color: AppColors.orange,
                title: 'Daily limit alert',
                subtitle: 'Notify when today\'s spending reaches the daily limit',
                value: settings.dailyLimitAlert,
                onChanged: (value) => settings.setDailyLimitAlert(value),
              ),
              _divider(),
              _switchRow(
                icon: Icons.track_changes_rounded,
                color: AppColors.purple,
                title: 'Monthly budget alert',
                subtitle: 'Notify when the monthly budget is reached',
                value: settings.monthlyBudgetAlert,
                onChanged: (value) => settings.setMonthlyBudgetAlert(value),
              ),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('Notification preview'),
            const SizedBox(height: 7),
            _previewCard(settings, expenses),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loading ? null : _sendTestNotification,
              icon: const Icon(Icons.notifications_none_rounded, size: 17),
              label: const Text('Send a test notification'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
            if (!_permissionGranted) ...[
              const SizedBox(height: 10),
              _permissionCard(),
            ],
            if (_loading) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17)),
          const Expanded(child: Column(children: [Text('Notifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Stay on top of your spending', style: TextStyle(fontSize: 9, color: AppColors.textSecondary))])),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _heroCard(SettingsProvider settings) {
    final enabled = settings.dailyReminder || settings.dailyLimitAlert || settings.monthlyBudgetAlert;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF078B67), Color(0xFF04684E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(19),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .17), blurRadius: 15, offset: const Offset(0, 7))],
      ),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: Icon(enabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, color: Colors.white, size: 23)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(enabled ? 'You\'re protected' : 'Notifications are off', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(enabled ? 'We\'ll help you stay within your plan.' : 'Turn on a reminder or budget alert below.', style: const TextStyle(color: Colors.white70, fontSize: 9))])),
          if (_dailyScheduled) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)));

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
      child: Column(children: children),
    );
  }

  Widget _switchRow({required IconData icon, required Color color, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 17)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary))])), Switch.adaptive(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary, activeTrackColor: AppColors.primary.withValues(alpha: .35))],),
    );
  }

  Widget _tapRow({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 17)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: onTap == null ? AppColors.textSecondary : AppColors.textPrimary)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary))])), Icon(Icons.chevron_right_rounded, size: 19, color: onTap == null ? AppColors.border : AppColors.textSecondary)]),
      ),
    );
  }

  Widget _previewCard(SettingsProvider settings, ExpenseProvider expenses) {
    final body = settings.dailyReminder ? 'Don\'t forget to log today\'s spending.' : 'Turn on reminders to see them here.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 18)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Spend Smart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(body, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary))])), Text('${expenses.todayExpenses.length} today', style: const TextStyle(fontSize: 8, color: AppColors.textSecondary))]),
    );
  }

  Widget _permissionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [const Icon(Icons.info_outline_rounded, color: AppColors.orange, size: 17), const SizedBox(width: 8), const Expanded(child: Text('Notification permission is off on this device.', style: TextStyle(fontSize: 9))), TextButton(onPressed: _requestPermission, child: const Text('Allow', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)))],),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 55, endIndent: 12, color: AppColors.border);

  String _formatTime(TimeOfDay time) => MaterialLocalizations.of(context).formatTimeOfDay(time, alwaysUse24HourFormat: false);

  Future<void> _toggleDailyReminder(bool value) async {
    if (value) await _requestPermission();
    if (!mounted) return;
    await context.read<SettingsProvider>().setDailyReminder(value);
    await _refreshPending();
  }

  Future<void> _pickTime(SettingsProvider settings) async {
    final time = await showTimePicker(context: context, initialTime: settings.notificationTime, helpText: 'Choose reminder time');
    if (time == null || !mounted) return;
    await settings.setNotificationTime(time);
    await _refreshPending();
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.instance.showTestNotification();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test notification sent')));
  }

  Future<void> _requestPermission() async {
    await NotificationService.instance.requestPermissions();
    final enabled = await NotificationService.instance.areNotificationsEnabled();
    if (mounted) setState(() => _permissionGranted = enabled ?? true);
  }

  Future<void> _refreshPending() async {
    final pending = await NotificationService.instance.pendingNotifications();
    if (mounted) setState(() => _dailyScheduled = pending.any((item) => item.id == 1001));
  }
}
