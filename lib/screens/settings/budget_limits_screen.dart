import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';

class BudgetLimitsScreen extends StatefulWidget {
  const BudgetLimitsScreen({super.key});

  @override
  State<BudgetLimitsScreen> createState() => _BudgetLimitsScreenState();
}

class _BudgetLimitsScreenState extends State<BudgetLimitsScreen> {
  late final TextEditingController monthlyController;
  late final TextEditingController dailyController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    monthlyController = TextEditingController(text: settings.monthlyBudget.toStringAsFixed(0));
    dailyController = TextEditingController(text: settings.dailyLimit.toStringAsFixed(0));
  }

  @override
  void dispose() {
    monthlyController.dispose();
    dailyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final expenses = context.watch<ExpenseProvider>();
    final currency = settings.currency;
    final monthlyBudget = double.tryParse(monthlyController.text) ?? settings.monthlyBudget;
    final dailyLimit = double.tryParse(dailyController.text) ?? settings.dailyLimit;

    return Scaffold(
      backgroundColor: context.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _budgetCard(
                    title: 'Monthly Budget',
                    icon: Icons.savings_rounded,
                    color: AppColors.primary,
                    controller: monthlyController,
                    spent: expenses.monthTotal,
                    limit: monthlyBudget,
                    currency: currency,
                  ),
                  const SizedBox(height: 12),
                  _budgetCard(
                    title: 'Daily Limit',
                    icon: Icons.alarm_on_rounded,
                    color: const Color(0xFF179A7A),
                    controller: dailyController,
                    spent: expenses.todayTotal,
                    limit: dailyLimit,
                    currency: currency,
                  ),
                  const SizedBox(height: 16),
                  const Text('Budget Alerts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          value: settings.dailyLimitAlert,
                          onChanged: settings.setDailyLimitAlert,
                          activeThumbColor: AppColors.primary,
      activeTrackColor: context.softGreenColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                          title: const Text('Notify when daily limit is reached', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        const Divider(height: 1, indent: 13, endIndent: 13),
                        SwitchListTile.adaptive(
                          value: settings.monthlyBudgetAlert,
                          onChanged: settings.setMonthlyBudgetAlert,
                          activeThumbColor: AppColors.primary,
      activeTrackColor: context.softGreenColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                          title: const Text('Notify when monthly budget is 80% used', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Set Budget', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 20, 8),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17)),
          const Expanded(child: Center(child: Text('Budget & Limits', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _budgetCard({required String title, required IconData icon, required Color color, required TextEditingController controller, required double spent, required double limit, required String currency}) {
    final remaining = (limit - spent).clamp(0, limit).toDouble();
    final progress = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(17), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 14, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: color)), const SizedBox(width: 9), Expanded(child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))), SizedBox(width: 92, height: 34, child: TextField(controller: controller, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.right, decoration: InputDecoration(prefixText: '৳ ', contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), filled: true, fillColor: context.fieldColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 8),
          Text('Spent: ${CurrencyUtils.format(spent, currency: currency)}', style: TextStyle(fontSize: 9, color: context.secondaryTextColor)),
          const SizedBox(height: 5),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: color.withValues(alpha: .12), valueColor: AlwaysStoppedAnimation(color))),
          const SizedBox(height: 5),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Remaining: ${CurrencyUtils.format(remaining, currency: currency)}', style: TextStyle(fontSize: 9, color: context.secondaryTextColor)), Text('${(progress * 100).round()}%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))]),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final monthly = double.tryParse(monthlyController.text.trim());
    final daily = double.tryParse(dailyController.text.trim());
    if (monthly == null || monthly <= 0 || daily == null || daily <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid budget amounts')));
      return;
    }
    final settings = context.read<SettingsProvider>();
    await settings.setBudgetLimits(monthlyBudget: monthly, dailyLimit: daily);
    if (mounted) Navigator.pop(context);
  }
}
