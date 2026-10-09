import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/expense.dart';
import '../../data/models/income.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_page_header.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int selectedTab = 0;
  int? highlightedWeekday;

  List<Expense> _monthExpenses(List<Expense> expenses) => expenses.where((expense) => expense.date.year == selectedMonth.year && expense.date.month == selectedMonth.month && !expense.isRecurring).toList();

  Map<String, double> _categoryTotals(List<Expense> expenses) {
    final totals = <String, double>{};
    for (final expense in expenses) {
      totals.update(expense.category, (value) => value + expense.amount, ifAbsent: () => expense.amount);
    }
    return totals;
  }

  double _monthIncome(ExpenseProvider provider) => provider.incomes.where((income) => income.date.year == selectedMonth.year && income.date.month == selectedMonth.month).fold<double>(0, (sum, income) => sum + income.amount);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final currency = context.watch<SettingsProvider>().currency;
    final expenses = _monthExpenses(provider.expenses);
    final categories = _categoryTotals(expenses);
    final total = expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final income = _monthIncome(provider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 112),
        children: [
          const AppPageHeader(title: 'Reports', subtitle: 'Understand your money'),
          const SizedBox(height: 5),
          _monthPicker(),
          const SizedBox(height: 10),
          _tabs(),
          const SizedBox(height: 12),
          if (selectedTab == 0) _overview(provider, expenses, categories, total, income, currency),
          if (selectedTab == 1) _categories(expenses, categories, total, currency),
          if (selectedTab == 2) _trends(provider, total, income, currency),
        ],
      ),
    );
  }

  Widget _monthPicker() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.outlineColor)),
      child: Row(
        children: [
          IconButton(onPressed: () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1)), icon: const Icon(Icons.chevron_left_rounded, size: 19, color: AppColors.primaryDark)),
          Expanded(child: Text(AppDateUtils.formatMonthYear(selectedMonth), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
          IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right_rounded, size: 19, color: AppColors.primaryDark)),
        ],
      ),
    );
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => selectedMonth = next);
  }

  Widget _tabs() {
    const labels = ['Overview', 'Categories', 'Trends'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.mutedSurfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(
          labels.length,
          (index) => Expanded(
            child: InkWell(
              onTap: () => setState(() => selectedTab = index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedTab == index ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: selectedTab == index ? Colors.white : context.secondaryTextColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overview(ExpenseProvider provider, List<Expense> expenses, Map<String, double> categories, double total, double income, String currency) {
    final settings = context.watch<SettingsProvider>();
    final elapsedDays = AppDateUtils.elapsedDaysInRange(
      DateTime(selectedMonth.year, selectedMonth.month, 1),
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0),
    );
    final dayTotals = _dayTotals(expenses);
    final highest = dayTotals.entries.isEmpty ? null : (dayTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
    final daysWithSpending = dayTotals.length;
    final dailyAverage = elapsedDays == 0 ? 0.0 : total / elapsedDays;
    final topCategory = categories.entries.isEmpty ? null : (categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;

    return Column(
      children: [
        _spendingCard(total, expenses.length, currency),
        const SizedBox(height: 10),
        _incomeCard(income, provider.totalIncome, provider.balance, currency),
        const SizedBox(height: 14),
        _budgetSummary(settings, provider.todayTotal, provider.monthTotal, currency),
        const SizedBox(height: 14),
        _sectionTitle('Weekly Spending'),
        const SizedBox(height: 5),
        _weeklyChart(expenses, currency),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _statCard('Top Category', topCategory?.key ?? 'No data', topCategory == null ? '-' : CurrencyUtils.format(topCategory.value, currency: currency), Icons.category_rounded, onTap: topCategory == null ? null : () => setState(() => selectedTab = 1))), const SizedBox(width: 8), Expanded(child: _statCard('Daily Average', CurrencyUtils.format(dailyAverage, currency: currency), '$elapsedDays elapsed days', Icons.trending_up_rounded))]),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: _statCard('Highest Day', highest == null ? '-' : AppDateUtils.formatDate(DateTime(selectedMonth.year, selectedMonth.month, highest.key)), highest == null ? '-' : CurrencyUtils.format(highest.value, currency: currency), Icons.calendar_today_rounded)), const SizedBox(width: 8), Expanded(child: _statCard('No-spend Days', '${elapsedDays - daysWithSpending} days', 'Elapsed days', Icons.event_available_rounded))]),
        const SizedBox(height: 10),
        _insightCard(topCategory, highest, total, income, currency),
        if (expenses.isEmpty) ...[const SizedBox(height: 12), const EmptyState(title: 'No expenses this month', message: 'Add expenses to unlock more insights.', icon: Icons.bar_chart_rounded)],
      ],
    );
  }

  Widget _spendingCard(double total, int transactions, String currency) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF078B67), Color(0xFF04684E)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .17), blurRadius: 14, offset: const Offset(0, 6))]),
      child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Spending', style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 10)), const SizedBox(height: 2), Text(CurrencyUtils.format(total, currency: currency), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), Text('$transactions transactions', style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 9))]),), Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13), shape: BoxShape.circle), child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 25))]),
    );
  }

  Widget _incomeCard(double monthIncome, double totalIncome, double balance, String currency) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.outlineColor)),
      child: Column(children: [Row(children: [const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.primary), const SizedBox(width: 6), const Expanded(child: Text('Income & Balance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))), Text('Lifetime ${CurrencyUtils.format(totalIncome, currency: currency)}', style: TextStyle(fontSize: 8, color: context.secondaryTextColor))]), const SizedBox(height: 9), Row(children: [_miniMetric('This month', CurrencyUtils.format(monthIncome, currency: currency)), _verticalDivider(), _miniMetric('Available', CurrencyUtils.format(balance, currency: currency))])]),
    );
  }

  Widget _miniMetric(String label, String value) => Expanded(child: Column(children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 8, color: context.secondaryTextColor))]));

  Widget _verticalDivider() => Container(width: 1, height: 25, color: context.outlineColor);

  Widget _sectionTitle(String title) => Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)));

  Widget _budgetSummary(SettingsProvider settings, double todaySpent, double monthSpent, String currency) {
    final monthlyProgress = settings.monthlyBudget <= 0 ? 0.0 : (monthSpent / settings.monthlyBudget).clamp(0.0, 1.0).toDouble();
    final dailyProgress = settings.dailyLimit <= 0 ? 0.0 : (todaySpent / settings.dailyLimit).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.outlineColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Budget progress', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 8), _budgetLine('Monthly', monthSpent, settings.monthlyBudget, monthlyProgress, currency, AppColors.primary), const SizedBox(height: 8), _budgetLine('Today', todaySpent, settings.dailyLimit, dailyProgress, currency, AppColors.blue)]),
    );
  }

  Widget _budgetLine(String label, double spent, double limit, double progress, String currency, Color color) {
    return Row(children: [SizedBox(width: 48, child: Text(label, style: TextStyle(fontSize: 9, color: context.secondaryTextColor))), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: color.withValues(alpha: .12), valueColor: AlwaysStoppedAnimation(color)))), const SizedBox(width: 8), Text('${CurrencyUtils.format(spent, currency: currency)} / ${CurrencyUtils.format(limit, currency: currency)}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700))]);
  }

  Widget _insightCard(MapEntry<String, double>? topCategory, MapEntry<int, double>? highest, double total, double income, String currency) {
    final message = topCategory == null
        ? 'Add expenses to receive personalized spending insights.'
        : 'Your highest category is ${topCategory.key} at ${CurrencyUtils.format(topCategory.value, currency: currency)}.';
    final secondary = highest == null
        ? 'No highest-spend day yet.'
        : 'Your highest day reached ${CurrencyUtils.format(highest.value, currency: currency)}.';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [context.softGreenColor, context.softGreenColor.withValues(alpha: .45)]), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [Container(width: 31, height: 31, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Smart insight', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(message, style: const TextStyle(fontSize: 9)), const SizedBox(height: 2), Text(secondary, style: TextStyle(fontSize: 8, color: context.secondaryTextColor))]))]),
    );
  }

  Widget _weeklyChart(List<Expense> expenses, String currency) {
    final values = List<double>.filled(7, 0);
    for (final expense in expenses) {
      values[expense.date.weekday % 7] += expense.amount;
    }
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final selectedValue = highlightedWeekday == null ? null : values[highlightedWeekday!];
    return Container(
      height: 177,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 5),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(child: BarChart(
        BarChartData(
          maxY: maxValue == 0 ? 100 : maxValue * 1.25,
          minY: 0,
          barTouchData: BarTouchData(enabled: true, touchCallback: (event, response) {
            final index = response?.spot?.touchedBarGroupIndex;
            if (index != null) setState(() => highlightedWeekday = index);
          }),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt().clamp(0, 6);
                  return Text(labels[index], style: TextStyle(fontSize: 8, color: context.secondaryTextColor));
                },
              ),
            ),
          ),
          barGroups: List.generate(
            7,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: values[index],
                  width: 15,
                  color: highlightedWeekday == index || (highlightedWeekday == null && values[index] == maxValue && maxValue > 0) ? AppColors.primary : const Color(0xFF65CDB0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
        ),
          )),
          if (selectedValue != null)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text('${labels[highlightedWeekday!]} • ${CurrencyUtils.format(selectedValue, currency: currency)}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.primaryDark))),
        ],
      ),
    );
  }

  Map<int, double> _dayTotals(List<Expense> expenses) {
    final result = <int, double>{};
    for (final expense in expenses) {
      result.update(expense.date.day, (value) => value + expense.amount, ifAbsent: () => expense.amount);
    }
    return result;
  }

  Widget _statCard(String label, String value, String sublabel, IconData icon, {VoidCallback? onTap}) {
    final card = Container(
      height: 88,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 15, color: AppColors.primary), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 8, color: context.secondaryTextColor)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), Text(sublabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: context.secondaryTextColor))]),
    );
    return onTap == null ? card : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: card);
  }

  Widget _categories(List<Expense> expenses, Map<String, double> categoryTotals, double total, String currency) {
    final entries = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(children: [Container(height: 238, decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(17)), child: Stack(alignment: Alignment.center, children: [PieChart(PieChartData(centerSpaceRadius: 55, sectionsSpace: 2, startDegreeOffset: -90, sections: entries.map((entry) => PieChartSectionData(value: entry.value, color: CategoryIcon.getColor(entry.key), radius: 31, showTitle: false)).toList())), Column(mainAxisSize: MainAxisSize.min, children: [Text(CurrencyUtils.format(total, currency: currency), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), Text('Total', style: TextStyle(fontSize: 9, color: context.secondaryTextColor))])])), const SizedBox(height: 12), if (entries.isEmpty) const EmptyState(title: 'No categories yet', message: 'Add expenses to see your breakdown.', icon: Icons.pie_chart_outline_rounded) else ...entries.map((entry) { final percentage = total == 0 ? 0 : entry.value / total * 100; return Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: CategoryIcon.getColor(entry.key), shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 10))), Text('${percentage.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(width: 15), SizedBox(width: 70, child: Text(CurrencyUtils.format(entry.value, currency: currency), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))) ])); })]);
  }

  Widget _trends(ExpenseProvider provider, double spending, double income, String currency) {
    final settings = context.watch<SettingsProvider>();
    final balance = income - spending;
    final monthExpenses = _monthExpenses(provider.expenses);
    final monthIncomes = provider.incomes.where((item) => item.date.year == selectedMonth.year && item.date.month == selectedMonth.month).toList();
    final spendingByDay = _dailyExpenseTotals(monthExpenses);
    final incomeByDay = _dailyIncomeTotals(monthIncomes);
    final daysOverBudget = settings.dailyLimit <= 0 ? 0 : spendingByDay.where((value) => value > settings.dailyLimit).length;
    final elapsedDays = AppDateUtils.elapsedDaysInRange(
      DateTime(selectedMonth.year, selectedMonth.month, 1),
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0),
    );
    final average = elapsedDays == 0 ? 0.0 : spendingByDay.fold<double>(0, (sum, value) => sum + value) / elapsedDays;
    return Column(
      children: [
        _incomeCard(income, provider.totalIncome, provider.balance, currency),
        const SizedBox(height: 12),
        _trendChart(spendingByDay, incomeByDay, settings.dailyLimit, currency),
        const SizedBox(height: 12),
        _comparisonChart(income, spending, currency),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _trendMetric('Daily average', CurrencyUtils.format(average, currency: currency), Icons.show_chart_rounded, AppColors.blue)), const SizedBox(width: 8), Expanded(child: _trendMetric('Budget crossed', '$daysOverBudget ${daysOverBudget == 1 ? 'day' : 'days'}', Icons.warning_amber_rounded, daysOverBudget > 0 ? AppColors.orange : AppColors.primary))]),
        const SizedBox(height: 8),
        _trendMetric('Net change', CurrencyUtils.format(balance, currency: currency), balance >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, balance >= 0 ? AppColors.primary : AppColors.red),
      ],
    );
  }

  List<double> _dailyExpenseTotals(List<Expense> expenses) {
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final values = List<double>.filled(daysInMonth, 0);
    for (final expense in expenses) {
      values[expense.date.day - 1] += expense.amount;
    }
    return values;
  }

  List<double> _dailyIncomeTotals(List<Income> incomes) {
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final values = List<double>.filled(daysInMonth, 0);
    for (final income in incomes) {
      values[income.date.day - 1] += income.amount;
    }
    return values;
  }

  Widget _trendChart(List<double> spending, List<double> income, double dailyLimit, String currency) {
    final highestSpending = [...spending, dailyLimit].fold<double>(0, (highest, value) => value > highest ? value : highest);
    final spendingMaxY = highestSpending == 0 ? 100.0 : highestSpending * 1.25;
    final highestIncome = income.fold<double>(0, (highest, value) => value > highest ? value : highest);
    final incomeScale = highestIncome <= 0 ? 0.0 : spendingMaxY * .9 / highestIncome;
    final incomeSpots = List.generate(income.length, (index) => FlSpot(index.toDouble(), income[index] * incomeScale));
    final daysInMonth = spending.length;
    String compactAmount(double value) {
      if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
      if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
      return value.round().toString();
    }

    String currencyAmount(double value) => '${currency == 'BDT' ? '৳' : currency}${compactAmount(value)}';

    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 5),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(17)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Money flow trend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('Spending focus • left scale: expense • right scale: income', style: TextStyle(fontSize: 8, color: context.secondaryTextColor)),
          const SizedBox(height: 7),
          Row(children: [_legendDot(AppColors.primary, 'Spending'), const SizedBox(width: 11), _legendDot(AppColors.blue, 'Income'), const SizedBox(width: 11), _legendDot(AppColors.orange, 'Daily budget', dashed: true)]),
          const SizedBox(height: 7),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (daysInMonth - 1).toDouble(),
                minY: 0,
                maxY: spendingMaxY,
                extraLinesData: ExtraLinesData(
                  horizontalLines: dailyLimit > 0
                      ? [HorizontalLine(y: dailyLimit, color: AppColors.orange, strokeWidth: 1.5, dashArray: [6, 4])]
                      : const [],
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: spendingMaxY / 3, getDrawingHorizontalLine: (_) => FlLine(color: context.outlineColor, strokeWidth: .7)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 27, interval: spendingMaxY / 3, getTitlesWidget: (value, meta) => Text(currencyAmount(value), style: TextStyle(fontSize: 7, color: context.secondaryTextColor)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: highestIncome > 0, reservedSize: 29, interval: spendingMaxY / 3, getTitlesWidget: (value, meta) => Text(currencyAmount(incomeScale == 0 ? 0 : value / incomeScale), style: TextStyle(fontSize: 7, color: AppColors.blue)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 18, interval: daysInMonth > 14 ? 5 : 1, getTitlesWidget: (value, meta) {
                    final day = value.toInt() + 1;
                    if (day < 1 || day > daysInMonth || (daysInMonth > 14 && day != 1 && day != daysInMonth && (day - 1) % 5 != 0)) return const SizedBox.shrink();
                    return Text('$day', style: TextStyle(fontSize: 8, color: context.secondaryTextColor));
                  })),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(spending.length, (index) => FlSpot(index.toDouble(), spending[index])),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3.5,
                    preventCurveOverShooting: true,
                    dotData: FlDotData(show: spending.length <= 14, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 3, color: context.surfaceColor, strokeWidth: 2, strokeColor: AppColors.primary)),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primary.withValues(alpha: .25), AppColors.primary.withValues(alpha: .02)])),
                  ),
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: false,
                    color: AppColors.blue,
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: FlDotData(show: highestIncome > 0, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 3, color: context.surfaceColor, strokeWidth: 2, strokeColor: AppColors.blue)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, {bool dashed = false}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 15, child: dashed ? CustomPaint(painter: _DashedLegendPainter(color)) : Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 8, color: context.secondaryTextColor, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _comparisonChart(double income, double spending, String currency) {
    final maxValue = income > spending ? income : spending;
    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 7),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(17)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Income vs spending', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('This month at a glance', style: TextStyle(fontSize: 8, color: context.secondaryTextColor)),
          const SizedBox(height: 6),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxValue == 0 ? 100 : maxValue * 1.25,
                minY: 0,
                barTouchData: BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 17,
                    getTitlesWidget: (value, meta) => Text(value.toInt() == 0 ? 'Income' : 'Spent', style: TextStyle(fontSize: 8, color: context.secondaryTextColor)),
                  )),
                ),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: income, width: 42, color: AppColors.blue, borderRadius: BorderRadius.circular(5))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: spending, width: 42, color: AppColors.primary, borderRadius: BorderRadius.circular(5))]),
                ],
              ),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legendDot(AppColors.blue, 'Income'),
            const SizedBox(width: 14),
            _legendDot(AppColors.primary, 'Spending'),
          ]),
        ],
      ),
    );
  }

  Widget _trendMetric(String label, String value, IconData icon, Color color) {
  return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(14)), child: Row(children: [Container(width: 27, height: 27, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 15, color: color)), const SizedBox(width: 7), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: context.secondaryTextColor))]))]));
  }

}

class _DashedLegendPainter extends CustomPainter {
  final Color color;

  const _DashedLegendPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 5) {
      final endX = x + 3 > size.width ? size.width : x + 3;
      canvas.drawLine(Offset(x, size.height / 2), Offset(endX, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLegendPainter oldDelegate) => oldDelegate.color != color;
}
