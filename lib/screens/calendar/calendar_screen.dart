import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/category_icon.dart';
import '../add_expense/add_expense_redesign.dart';
import '../expense_details/expense_details_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime visibleMonth;
  late DateTime selectedDate;
  bool showCalendar = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    visibleMonth = DateTime(now.year, now.month);
    selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final monthExpenses = provider.expenses.where((expense) => expense.date.year == visibleMonth.year && expense.date.month == visibleMonth.month).toList();
    final selectedExpenses = provider.expenses.where((expense) => AppDateUtils.isSameDay(expense.date, selectedDate)).toList();
    final dayTotal = selectedExpenses.fold<double>(0, (sum, expense) => sum + expense.amount);

    return Scaffold(
      extendBody: true,
      backgroundColor: context.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _viewToggle(),
            if (showCalendar) ...[
              _monthHeader(),
              _calendarGrid(monthExpenses),
              Expanded(child: _selectedDayExpenses(selectedExpenses, dayTotal, settings.currency)),
            ] else
              Expanded(child: _historyList(provider.expenses, settings.currency)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar-add-expense',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
        child: const Icon(Icons.add_rounded, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: 1,
        onItemSelected: (index) {
          if (index == 0) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 20, 7),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17)),
          const Expanded(child: Center(child: Text('Expense History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _viewToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: context.mutedSurfaceColor, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(child: _toggleButton('List', Icons.receipt_long_rounded, !showCalendar)),
          Expanded(child: _toggleButton('Calendar', Icons.calendar_month_rounded, showCalendar)),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, IconData icon, bool selected) {
    return Container(
      height: 32,
      decoration: BoxDecoration(color: selected ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => setState(() => showCalendar = label == 'Calendar'),
        borderRadius: BorderRadius.circular(8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 13, color: selected ? Colors.white : context.secondaryTextColor), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: selected ? Colors.white : context.secondaryTextColor))]),
      ),
    );
  }

  Widget _monthHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 11, 20, 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: () => setState(() => visibleMonth = DateTime(visibleMonth.year, visibleMonth.month - 1)), icon: const Icon(Icons.chevron_left_rounded, size: 21, color: AppColors.primaryDark)),
          Text(AppDateUtils.formatMonthYear(visibleMonth), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          IconButton(onPressed: () => setState(() => visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + 1)), icon: const Icon(Icons.chevron_right_rounded, size: 21, color: AppColors.primaryDark)),
        ],
      ),
    );
  }

  Widget _calendarGrid(List<Expense> monthExpenses) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final leadingEmpty = firstDay.weekday % 7;
    final cells = <Widget>[];
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    for (final day in weekdays) {
        cells.add(Center(child: Text(day, style: TextStyle(fontSize: 8, color: context.secondaryTextColor, fontWeight: FontWeight.w600))));
    }
    for (var i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(visibleMonth.year, visibleMonth.month, day);
      final expenses = monthExpenses.where((expense) => AppDateUtils.isSameDay(expense.date, date)).toList();
      cells.add(_dayCell(date, expenses));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        childAspectRatio: 1.45,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: cells,
      ),
    );
  }

  Widget _dayCell(DateTime date, List<Expense> expenses) {
    final selected = AppDateUtils.isSameDay(date, selectedDate);
    final today = AppDateUtils.isSameDay(date, DateTime.now());
    final total = expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
    return InkWell(
      onTap: () => setState(() => selectedDate = date),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? AppColors.primary : today ? context.softGreenColor : Colors.transparent, shape: BoxShape.circle),
          child: Text('${date.day}', style: TextStyle(fontSize: 9, fontWeight: selected || today ? FontWeight.w800 : FontWeight.w500, color: selected ? Colors.white : context.primaryTextColor)),
          ),
          if (expenses.isNotEmpty)
            Container(width: 4, height: 4, decoration: BoxDecoration(color: total > 500 ? AppColors.orange : AppColors.primary, shape: BoxShape.circle)),
        ],
      ),
    );
  }

  Widget _selectedDayExpenses(List<Expense> expenses, double total, String currency) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppDateUtils.formatDate(selectedDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), Text(CurrencyUtils.format(total, currency: currency), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]),
        const SizedBox(height: 6),
        if (expenses.isEmpty)
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(15)), child: Text('No expenses on this day', style: TextStyle(fontSize: 10, color: context.secondaryTextColor)))
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [for (var i = 0; i < expenses.length; i++) ...[_expenseRow(expenses[i], currency), if (i < expenses.length - 1) const Divider(height: 1, indent: 42)]]),
          ),
      ],
    );
  }

  Widget _expenseRow(Expense expense, String currency) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseDetailsScreen(expense: expense))),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CategoryIcon(category: expense.category, size: 34),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(expense.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(expense.category, style: TextStyle(fontSize: 9, color: context.secondaryTextColor))])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(CurrencyUtils.format(expense.amount, currency: currency), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(AppDateUtils.formatTime(expense.date), style: TextStyle(fontSize: 8, color: context.secondaryTextColor))]),
          ],
        ),
      ),
    );
  }

  Widget _historyList(List<Expense> expenses, String currency) {
    final sorted = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
    final groups = <DateTime, List<Expense>>{};
    for (final expense in sorted) {
      final day = DateTime(expense.date.year, expense.date.month, expense.date.day);
      groups.putIfAbsent(day, () => []).add(expense);
    }

    if (groups.isEmpty) {
    return Center(child: Text('No expenses yet', style: TextStyle(fontSize: 11, color: context.secondaryTextColor)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      children: groups.entries.map((entry) {
        final total = entry.value.fold<double>(0, (sum, expense) => sum + expense.amount);
        final dayTitle = AppDateUtils.isSameDay(entry.key, DateTime.now())
            ? 'Today'
            : AppDateUtils.isSameDay(entry.key, DateTime.now().subtract(const Duration(days: 1)))
                ? 'Yesterday'
                : AppDateUtils.formatDate(entry.key);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dayTitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), Text(CurrencyUtils.format(total, currency: currency), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [for (var i = 0; i < entry.value.length; i++) ...[_expenseRow(entry.value[i], currency), if (i < entry.value.length - 1) const Divider(height: 1, indent: 42)]]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

}
