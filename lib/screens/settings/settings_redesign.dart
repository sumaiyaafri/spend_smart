import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_page_header.dart';
import 'budget_limits_screen.dart';
import 'backup_restore_screen.dart';
import 'notifications_screen.dart';
import 'recurring_expenses_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 116),
        children: [
          _header(),
          const SizedBox(height: 16),
          _profileCard(settings.userName),
          const SizedBox(height: 14),
          _sectionTitle(context, 'Profile'),
          const SizedBox(height: 6),
          _card(
            context,
            children: [
              _settingRow(
                context,
                icon: Icons.person_outline_rounded,
                color: AppColors.primary,
                title: 'Your name',
                subtitle: settings.userName.isEmpty ? 'Add your name for a personal touch' : settings.userName,
                trailing: Icon(Icons.edit_rounded, size: 16, color: context.secondaryTextColor),
                onTap: () => _editName(context, settings),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionTitle(context, 'Preferences'),
          const SizedBox(height: 6),
          _card(
            context,
            children: [
              _settingRow(
                context,
                icon: Icons.palette_outlined,
                color: AppColors.purple,
                title: 'Appearance',
                subtitle: 'Choose how Spend Smart looks',
                child: _themeSelector(context, settings),
              ),
              _divider(context),
              _settingRow(
                context,
                icon: Icons.payments_rounded,
                color: AppColors.orange,
                title: 'Currency',
                subtitle: settings.currency == 'BDT' ? 'Bangladeshi Taka' : settings.currency,
                trailing: Text(
                  _currencyLabel(settings.currency),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
                onTap: () => _chooseCurrency(context, settings),
              ),
              _divider(context),
              _settingRow(
                context,
                icon: Icons.notifications_active_outlined,
                color: AppColors.primary,
                title: 'Notifications',
                subtitle: settings.dailyReminder ? 'Reminders and budget alerts are on' : 'Manage reminders and budget alerts',
                trailing: Icon(Icons.chevron_right_rounded, size: 19, color: context.secondaryTextColor),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionTitle(context, 'Spending Plan'),
          const SizedBox(height: 6),
          _card(
            context,
            children: [
              _settingRow(
                context,
                icon: Icons.track_changes_rounded,
                color: AppColors.primary,
                title: 'Budget & Limits',
                subtitle: 'Set monthly budget and daily spending limit',
                trailing: Icon(Icons.chevron_right_rounded, size: 19, color: context.secondaryTextColor),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetLimitsScreen())),
              ),
              _divider(context),
              _settingRow(
                context,
                icon: Icons.event_repeat_rounded,
                color: AppColors.orange,
                title: 'Recurring Expenses',
                subtitle: 'Manage monthly payments and reminders',
                trailing: Icon(Icons.chevron_right_rounded, size: 19, color: context.secondaryTextColor),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringExpensesScreen())),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionTitle(context, 'Data & Privacy'),
          const SizedBox(height: 6),
          _card(
            context,
            children: [
              _settingRow(context, icon: Icons.cloud_upload_outlined, color: AppColors.blue, title: 'Backup & Restore', subtitle: 'Restore a previous Spend Smart backup', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen(showExport: false, showRestore: true)))),
              _divider(context),
              _settingRow(context, icon: Icons.download_rounded, color: AppColors.primary, title: 'Export Data', subtitle: 'Create a portable JSON backup', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen(showExport: true, showRestore: false)))),
            ],
          ),
          const SizedBox(height: 14),
          _sectionTitle(context, 'App'),
          const SizedBox(height: 6),
          _card(
            context,
            children: [
              _settingRow(context, icon: Icons.auto_stories_outlined, color: AppColors.blue, title: 'View Onboarding', subtitle: 'Explore the introduction pages again', onTap: settings.resetOnboarding),
              _divider(context),
              _settingRow(context, icon: Icons.info_outline_rounded, color: AppColors.textSecondary, title: 'About Spend Smart', subtitle: 'Version 1.0.0 • 100% offline'),
            ],
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_outline_rounded, size: 13, color: context.secondaryTextColor), const SizedBox(width: 5), Text('Your data stays on your device', style: TextStyle(fontSize: 10, color: context.secondaryTextColor))]),
        ],
      ),
    );
  }

  Widget _header() {
    return const AppPageHeader(title: 'Settings', subtitle: 'Personalize your spending space');
  }

  Widget _profileCard(String userName) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF078B67), Color(0xFF04684E)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .16), blurRadius: 14, offset: const Offset(0, 6))]),
      child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 21)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(userName.isEmpty ? 'Spend Smart' : userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('Simple, private money tracking', style: TextStyle(color: Colors.white70, fontSize: 9))])), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)), child: const Text('OFFLINE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))) ]),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.secondaryTextColor)));

  Widget _card(BuildContext context, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(17), border: Border.all(color: context.outlineColor)),
      child: Column(children: children),
    );
  }

  Widget _settingRow(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle, Widget? child, Widget? trailing, VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 17, color: color)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(subtitle, style: TextStyle(fontSize: 8, color: context.secondaryTextColor))])), if (child != null) child else if (trailing != null) trailing else if (onTap != null) Icon(Icons.chevron_right_rounded, size: 19, color: context.secondaryTextColor)]),
    );
    return onTap == null ? content : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(17), child: content);
  }

  Widget _divider(BuildContext context) => Divider(height: 1, indent: 55, endIndent: 12, color: context.outlineColor);

  Widget _themeSelector(BuildContext context, SettingsProvider settings) {
    final options = [(ThemeMode.light, 'Light', Icons.light_mode_rounded), (ThemeMode.system, 'Auto', Icons.brightness_auto_rounded), (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded)];
    return Row(children: options.map((option) {
      final selected = settings.themeMode == option.$1;
      return Padding(padding: const EdgeInsets.only(left: 4), child: InkWell(onTap: () => settings.setThemeMode(option.$1), borderRadius: BorderRadius.circular(9), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: selected ? AppColors.primary : context.mutedSurfaceColor, borderRadius: BorderRadius.circular(9)), child: Icon(option.$3, size: 14, color: selected ? Colors.white : context.secondaryTextColor))));
    }).toList());
  }

  String _currencyLabel(String currency) {
    switch (currency) {
      case 'USD':
        return '\$ USD';
      case 'EUR':
        return '€ EUR';
      default:
        return '৳ BDT';
    }
  }

  Future<void> _chooseCurrency(BuildContext context, SettingsProvider settings) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: ['BDT', 'USD', 'EUR'].map((currency) => ListTile(title: Text(_currencyLabel(currency)), trailing: settings.currency == currency ? const Icon(Icons.check_rounded, color: AppColors.primary) : null, onTap: () => Navigator.pop(context, currency))).toList())),
    );
    if (selected != null) await settings.setCurrency(selected);
  }

  Future<void> _editName(BuildContext context, SettingsProvider settings) async {
    final controller = TextEditingController(text: settings.userName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 30,
          decoration: const InputDecoration(hintText: 'e.g. Noyon'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await settings.setUserName(name);
  }

}
