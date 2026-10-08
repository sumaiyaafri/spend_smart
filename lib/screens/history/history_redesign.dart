import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_page_header.dart';
import '../expense_details/expense_details_screen.dart';

enum HistoryFilter { today, week, month, all }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryFilter selectedFilter = HistoryFilter.all;
  String search = '';

  List<Expense> _filteredExpenses(List<Expense> expenses) {
    final query = search.trim().toLowerCase();
    final filtered = expenses.where((expense) {
      final matchesQuery = query.isEmpty || expense.title.toLowerCase().contains(query) || expense.category.toLowerCase().contains(query);
      if (!matchesQuery) return false;
      switch (selectedFilter) {
        case HistoryFilter.today:
          return AppDateUtils.isSameDay(expense.date, DateTime.now());
        case HistoryFilter.week:
          return AppDateUtils.isThisWeek(expense.date);
        case HistoryFilter.month:
          return AppDateUtils.isThisMonth(expense.date);
        case HistoryFilter.all:
          return true;
      }
    }).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  Map<DateTime, List<Expense>> _groupExpenses(List<Expense> expenses) {
    final groups = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      final day = DateTime(expense.date.year, expense.date.month, expense.date.day);
      groups.putIfAbsent(day, () => []).add(expense);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final filtered = _filteredExpenses(provider.expenses);
    final groups = _groupExpenses(filtered);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _header(),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const EmptyState(title: 'No expenses found', message: 'Try changing your search or filter.', icon: Icons.search_off_rounded)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 118),
                        children: groups.entries
                            .map((entry) => _groupCard(context, entry.key, entry.value, settings.currency))
                            .toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        const AppPageHeader(title: 'Expense History', subtitle: 'Browse your spending'),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Column(
            children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => search = value),
                  style: const TextStyle(fontSize: 10),
                  decoration: InputDecoration(
                    hintText: 'Search expenses...',
                    hintStyle: const TextStyle(fontSize: 10),
                    prefixIcon: const Icon(Icons.search_rounded, size: 17),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                    filled: true,
                    fillColor: context.fieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.outlineColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.outlineColor)),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              InkWell(
                onTap: _showFilterSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(width: 38, height: 38, decoration: BoxDecoration(color: context.softGreenColor, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.filter_alt_rounded, size: 17, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [_filterChip('Today', HistoryFilter.today), _filterChip('This Week', HistoryFilter.week), _filterChip('This Month', HistoryFilter.month), _filterChip('All', HistoryFilter.all)]),
          ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, HistoryFilter filter) {
    final selected = selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: selected ? Colors.white : context.secondaryTextColor)),
        selected: selected,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        backgroundColor: context.mutedSurfaceColor,
        selectedColor: AppColors.primary,
        side: BorderSide.none,
        onSelected: (_) => setState(() => selectedFilter = filter),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    final result = await showModalBottomSheet<HistoryFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: HistoryFilter.values
              .map(
                (filter) => ListTile(
                  title: Text(_filterName(filter)),
                  trailing: filter == selectedFilter ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () => Navigator.pop(context, filter),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (result != null) setState(() => selectedFilter = result);
  }

  String _filterName(HistoryFilter filter) {
    switch (filter) {
      case HistoryFilter.today:
        return 'Today';
      case HistoryFilter.week:
        return 'This Week';
      case HistoryFilter.month:
        return 'This Month';
      case HistoryFilter.all:
        return 'All expenses';
    }
  }

  Widget _groupCard(BuildContext context, DateTime day, List<Expense> expenses, String currency) {
    final total = expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
    final dateTitle = AppDateUtils.isSameDay(day, DateTime.now())
        ? 'Today'
        : AppDateUtils.isSameDay(day, DateTime.now().subtract(const Duration(days: 1)))
            ? 'Yesterday'
            : AppDateUtils.formatDate(day);

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 3, 2, 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dateTitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), Text(CurrencyUtils.format(total, currency: currency), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [for (var i = 0; i < expenses.length; i++) ...[_historyRow(context, expenses[i], currency), if (i < expenses.length - 1) const Divider(height: 1, indent: 42)]]),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(BuildContext context, Expense expense, String currency) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseDetailsScreen(expense: expense))),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CategoryIcon(category: expense.category, size: 34),
            const SizedBox(width: 9),
            Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(expense.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(expense.category, style: TextStyle(fontSize: 9, color: context.secondaryTextColor))]),
            ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(CurrencyUtils.format(expense.amount, currency: currency), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(AppDateUtils.formatTime(expense.date), style: TextStyle(fontSize: 8, color: context.secondaryTextColor))]),
          ],
        ),
      ),
    );
  }
}
