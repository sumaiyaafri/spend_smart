import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/expense.dart';
import '../../data/models/recurring_expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/category_icon.dart';
import '../add_expense/add_expense_redesign.dart';
import '../calendar/calendar_screen.dart';
import '../expense_details/expense_details_screen.dart';
import '../income/add_income_redesign.dart';
import '../income/income_screen_redesign.dart';
import '../settings/budget_limits_screen.dart';
import '../settings/backup_restore_screen.dart';
import '../settings/notifications_screen.dart';
import '../settings/recurring_expenses_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onSeeAll;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenSettings;

  const HomeScreen({super.key, this.onSeeAll, this.onOpenReports, this.onOpenSettings});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  RecurringExpense? _nextRecurring(
    List<RecurringExpense> items,
    ExpenseProvider provider,
  ) {
    if (items.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    RecurringExpense? next;
    var shortest = 9999;
    for (final item in items) {
      // Do not suggest a recurring payment again after it was paid this month.
      if (provider.isRecurringPaid(item)) continue;

      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final day = item.dueDay > daysInMonth ? daysInMonth : item.dueDay;
      var due = DateTime(now.year, now.month, day);
      if (due.isBefore(today)) due = DateTime(now.year, now.month + 1, item.dueDay);
      final days = due.difference(today).inDays;
      if (days < shortest) {
        shortest = days;
        next = item;
      }
    }
    return next;
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;
    final recentExpenses = provider.expenses.take(3).toList();
    final recurring = provider.recurringExpenses.where((item) => item.active).toList();
    final nextRecurring = _nextRecurring(recurring, provider);
    final recurringTotal = recurring.fold<double>(0, (sum, item) => sum + item.amount);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: provider.loadExpenses,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 118),
          children: [
            _buildHeader(context, settings),
            const SizedBox(height: 18),
            _TodayCard(
              amount: CurrencyUtils.format(
                provider.todayTotal,
                currency: currency,
              ),
              transactions: provider.todayExpenses.length,
              dailyLimit: CurrencyUtils.format(settings.dailyLimit, currency: currency),
              remaining: CurrencyUtils.format(
                (settings.dailyLimit - provider.todayTotal).clamp(0, settings.dailyLimit).toDouble(),
                currency: currency,
              ),
              progress: settings.dailyLimit <= 0 ? 0 : (provider.todayTotal / settings.dailyLimit).clamp(0.0, 1.0).toDouble(),
            ),
            const SizedBox(height: 12),
            _MonthCard(
              amount: CurrencyUtils.format(
                provider.monthTotal,
                currency: currency,
              ),
              transactions: provider.currentMonthExpenses.length,
              budget: CurrencyUtils.format(settings.monthlyBudget, currency: currency),
              remaining: CurrencyUtils.format(
                (settings.monthlyBudget - provider.monthTotal).clamp(0, settings.monthlyBudget).toDouble(),
                currency: currency,
              ),
              progress: settings.monthlyBudget <= 0 ? 0 : (provider.monthTotal / settings.monthlyBudget)
                  .clamp(0.0, 1.0)
                  .toDouble(),
            ),
            const SizedBox(height: 12),
            _IncomeOverviewCard(
              monthIncome: CurrencyUtils.format(provider.monthIncome, currency: currency),
              totalIncome: CurrencyUtils.format(provider.totalIncome, currency: currency),
              balance: CurrencyUtils.format(provider.balance, currency: currency),
              onManage: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomeScreen())),
            ),
            if (recurring.isNotEmpty) ...[
              const SizedBox(height: 12),
              _RecurringSummaryCard(
                count: recurring.length,
                monthlyTotal: CurrencyUtils.format(recurringTotal, currency: currency),
                nextTitle: nextRecurring?.title ?? 'No upcoming payment',
                nextDue: nextRecurring == null ? '-' : '${nextRecurring.dueDay}${_ordinal(nextRecurring.dueDay)} of this month',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringExpensesScreen())),
              ),
            ],
            const SizedBox(height: 14),
            _buildQuickActions(context),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Expenses',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'See all',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (recentExpenses.isEmpty)
              _EmptyRecentExpense(onAdd: () => _openAddExpense(context))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: recentExpenses
                      .map(
                        (expense) => _RecentExpenseRow(
                          title: expense.title,
                          category: expense.category,
                          amount: CurrencyUtils.format(
                            expense.amount,
                            currency: currency,
                          ),
                          date: expense.date,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ExpenseDetailsScreen(expense: expense),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SettingsProvider settings) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()},',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                settings.userName.isEmpty ? 'Spend Smart 👋' : '${settings.userName} 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                AppDateUtils.formatDateWithDay(DateTime.now()),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 2),
            child: IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: const Icon(Icons.notifications_rounded, size: 20),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              tooltip: 'Notifications',
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        'Quick Add',
        Icons.wallet_rounded,
        AppColors.orange,
        () => _showQuickAdd(context),
      ),
      _QuickAction('Income', Icons.account_balance_wallet_rounded, AppColors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomeScreen()))),
      _QuickAction(
        'Calendar',
        Icons.calendar_month_rounded,
        const Color(0xFF4387D8),
        () => _openCalendar(context),
      ),
      _QuickAction('More', Icons.tune_rounded, const Color(0xFF35B98D), () => _showMore(context)),
    ];

    return Row(
      children: actions
          .map(
            (action) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: action.onTap,
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: action.color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(action.icon, size: 18, color: action.color),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          action.label,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _openAddExpense(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
  }

  Future<void> _showQuickAdd(BuildContext context) async {
    final provider = context.read<ExpenseProvider>();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickAddSheet(
        recentExpenses: provider.expenses.take(3).toList(),
        onAdd: provider.addExpense,
        onFullForm: () => _openAddExpense(context),
      ),
    );
  }

  void _openCalendar(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CalendarScreen()),
    );
  }

  Future<void> _showMore(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('More', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
              _moreTile(sheetContext, Icons.track_changes_rounded, 'Budget & Limits', 'Set monthly budget and daily limit', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetLimitsScreen()))),
              _moreTile(sheetContext, Icons.event_repeat_rounded, 'Recurring Expenses', 'Manage monthly payments and reminders', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringExpensesScreen()))),
              _moreTile(sheetContext, Icons.add_card_rounded, 'Add Income', 'Record salary, bonus or other income', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddIncomeScreen()))),
              _moreTile(sheetContext, Icons.account_balance_wallet_rounded, 'Income & Balance', 'Review all money received', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomeScreen()))),
              _moreTile(sheetContext, Icons.insights_rounded, 'Smart Insights', 'See trends and spending insights', onOpenReports),
              _moreTile(sheetContext, Icons.settings_rounded, 'Settings', 'Personalize your Spend Smart space', onOpenSettings),
            _moreTile(sheetContext, Icons.ios_share_rounded, 'Export & Backup', 'Save or restore your records', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen()))),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback? action) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 19, color: AppColors.primary)),
      title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 9)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 19),
      onTap: () {
        Navigator.pop(context);
        if (action != null) Future<void>.microtask(action);
      },
    );
  }

}

class _TodayCard extends StatelessWidget {
  final String amount;
  final int transactions;
  final String dailyLimit;
  final String remaining;
  final double progress;

  const _TodayCard({
    required this.amount,
    required this.transactions,
    required this.dailyLimit,
    required this.remaining,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF078B67), Color(0xFF056B53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Spending",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .88),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$transactions transactions',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 16, right: 3),
                child: _BarChartIcon(),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Daily limit: $dailyLimit',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .84),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 7),
          _ProgressBar(progress: progress, foreground: Colors.white),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$remaining left today',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontSize: 9,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final String amount;
  final int transactions;
  final String budget;
  final String remaining;
  final double progress;

  const _MonthCard({
    required this.amount,
    required this.transactions,
    required this.budget,
    required this.remaining,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Month',
                    style: TextStyle(color: secondary, fontSize: 10),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$transactions transactions',
                    style: TextStyle(color: secondary, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Budget: $budget',
            style: TextStyle(color: secondary, fontSize: 10),
          ),
          const SizedBox(height: 6),
          _ProgressBar(progress: progress, foreground: AppColors.primary),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$remaining remaining',
                style: TextStyle(color: secondary, fontSize: 9),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: secondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomeOverviewCard extends StatelessWidget {
  final String monthIncome;
  final String totalIncome;
  final String balance;
  final VoidCallback onManage;

  const _IncomeOverviewCard({required this.monthIncome, required this.totalIncome, required this.balance, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 9),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 9),
              const Expanded(child: Text('Income Overview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
              TextButton(
                onPressed: onManage,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(58, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Manage', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _incomeStat('This month', monthIncome, secondary)),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(child: _incomeStat('Lifetime income', totalIncome, secondary)),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(child: _incomeStat('Available now', balance, secondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _incomeStat(String label, String value, Color secondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondary, fontSize: 8)),
        ],
      ),
    );
  }
}

class _RecurringSummaryCard extends StatelessWidget {
  final int count;
  final String monthlyTotal;
  final String nextTitle;
  final String nextDue;
  final VoidCallback onTap;

  const _RecurringSummaryCard({required this.count, required this.monthlyTotal, required this.nextTitle, required this.nextDue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.outlineColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.event_repeat_rounded, size: 18, color: AppColors.orange)),
            const SizedBox(width: 9),
            const Expanded(child: Text('Recurring payments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
            Icon(Icons.chevron_right_rounded, size: 19, color: secondary),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _stat('Monthly total', monthlyTotal, secondary)),
            Container(width: 1, height: 27, color: context.outlineColor),
            Expanded(child: _stat('$count active', 'scheduled', secondary)),
          ]),
          const SizedBox(height: 9),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: context.mutedSurfaceColor, borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.primary), const SizedBox(width: 6), Expanded(child: Text('Next: $nextTitle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))), Text(nextDue, style: TextStyle(fontSize: 8, color: secondary, fontWeight: FontWeight.w600))])),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, Color secondary) {
    return Column(children: [Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 8, color: secondary))]);
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color foreground;

  const _ProgressBar({required this.progress, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(height: 7, color: foreground.withValues(alpha: .17)),
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                color: foreground,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartIcon extends StatelessWidget {
  const _BarChartIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_bar(14), _bar(26), _bar(20)],
      ),
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 7,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class _RecentExpenseRow extends StatelessWidget {
  final String title;
  final String category;
  final String amount;
  final DateTime date;
  final VoidCallback onTap;

  const _RecentExpenseRow({
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            CategoryIcon(category: category, size: 34),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: TextStyle(color: secondary, fontSize: 9),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Today, ${AppDateUtils.formatTime(date)}',
                  style: TextStyle(color: secondary, fontSize: 8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecentExpense extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyRecentExpense({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('No expenses yet', style: TextStyle(fontSize: 12)),
          ),
          TextButton(onPressed: onAdd, child: const Text('Add one')),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _QuickAction(this.label, this.icon, this.color, this.onTap);
}

class _QuickAddSheet extends StatefulWidget {
  final List<Expense> recentExpenses;
  final Future<void> Function(Expense expense) onAdd;
  final VoidCallback onFullForm;

  const _QuickAddSheet({required this.recentExpenses, required this.onAdd, required this.onFullForm});

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final amountController = TextEditingController(text: '250');
  String selectedCategory = 'Food & Dining';
  String selectedTitle = 'Quick expense';
  bool saving = false;

  final categories = const [
    ('Food', 'Food & Dining', Icons.restaurant_rounded, AppColors.orange),
    ('Transport', 'Transport', Icons.directions_bus_rounded, AppColors.blue),
    ('Shopping', 'Shopping', Icons.shopping_bag_rounded, AppColors.purple),
    ('Bills', 'Bills', Icons.receipt_long_rounded, AppColors.primary),
    ('More', 'Others', Icons.more_horiz_rounded, AppColors.textSecondary),
  ];

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 14 + bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 15),
            const Text('Quick Add Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            _amountField(),
            const SizedBox(height: 12),
            _categoryPicker(),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent / Favourites', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 5),
            if (widget.recentExpenses.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('Your recent expenses will appear here', style: TextStyle(fontSize: 11)))
            else
              ...widget.recentExpenses.map(_recentRow),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton(
                onPressed: saving ? null : _save,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onFullForm();
              },
              child: const Text('Full Form  →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Container(width: 34, height: 4, decoration: BoxDecoration(color: Colors.black.withValues(alpha: .16), borderRadius: BorderRadius.circular(4)));

  Widget _amountField() {
    return TextField(
      controller: amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        prefixText: '৳ ',
        suffixIcon: IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: amountController.clear),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      ),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
  }

  Widget _categoryPicker() {
    return Row(
      children: categories.map((category) {
        final selected = selectedCategory == category.$2;
        return Expanded(
          child: GestureDetector(
            onTap: () async {
              if (category.$2 == 'Others') {
                await _showMoreCategories();
              } else if (mounted) {
                setState(() => selectedCategory = category.$2);
              }
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: category.$4.withValues(alpha: selected ? .22 : .10), borderRadius: BorderRadius.circular(11), border: selected ? Border.all(color: category.$4.withValues(alpha: .55), width: 1.2) : null),
                  child: Icon(category.$3, size: 18, color: category.$4),
                ),
                const SizedBox(height: 4),
                Text(category.$1, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showMoreCategories() async {
    const options = [
      ('Health', Icons.favorite_rounded, AppColors.red),
      ('Education', Icons.school_rounded, AppColors.blue),
      ('Entertainment', Icons.movie_rounded, AppColors.purple),
      ('Gifts', Icons.card_giftcard_rounded, AppColors.orange),
      ('Travel', Icons.flight_takeoff_rounded, AppColors.primary),
      ('Others', Icons.more_horiz_rounded, AppColors.textSecondary),
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map((option) => InkWell(
                    onTap: () => Navigator.pop(sheetContext, option.$1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(width: 92, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: option.$3.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(option.$2, size: 19, color: option.$3), const SizedBox(height: 4), Text(option.$1, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600))])),
                  )).toList(),
            ),
          ]),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => selectedCategory = selected);
  }

  Widget _recentRow(Expense expense) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          CategoryIcon(category: expense.category, size: 30),
          const SizedBox(width: 8),
          Expanded(child: Text(expense.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
          Text('৳ ${expense.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(width: 7),
          InkWell(
            onTap: () => setState(() {
              amountController.text = expense.amount.toStringAsFixed(0);
              selectedCategory = expense.category;
              selectedTitle = expense.title;
            }),
            borderRadius: BorderRadius.circular(20),
            child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: AppColors.softGreen, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, size: 17, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount first')));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onAdd(Expense(title: selectedTitle, amount: amount, category: selectedCategory, date: DateTime.now()));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add expense: $error')));
      }
    }
  }
}
