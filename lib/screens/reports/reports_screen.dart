import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/empty_state.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<Expense> _monthExpenses(List<Expense> expenses) {
    return expenses.where((expense) {
      return expense.date.year == selectedMonth.year &&
          expense.date.month == selectedMonth.month;
    }).toList();
  }

  Map<String, double> _categoryTotals(List<Expense> expenses) {
    final Map<String, double> result = {};

    for (final expense in expenses) {
      result.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    return result;
  }

  void _previousMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();

    final next = DateTime(selectedMonth.year, selectedMonth.month + 1);

    final currentMonth = DateTime(now.year, now.month);

    if (next.isAfter(currentMonth)) {
      return;
    }

    setState(() {
      selectedMonth = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    final currency = context.watch<SettingsProvider>().currency;

    final expenses = _monthExpenses(provider.expenses);

    final categoryTotals = _categoryTotals(expenses);

    final total = expenses.fold<double>(0, (sum, item) => sum + item.amount);

    final average = expenses.isEmpty ? 0.0 : total / expenses.length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          const Text(
            'Reports',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),

                Expanded(
                  child: Text(
                    AppDateUtils.formatMonthYear(selectedMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),

                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF078B67), Color(0xFF04684E)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Spending',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),

                const SizedBox(height: 5),

                Text(
                  CurrencyUtils.format(total, currency: currency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${expenses.length} transactions',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          if (expenses.isEmpty)
            const EmptyState(
              title: 'No report available',
              message: 'Add some expenses for this month to see analytics.',
              icon: Icons.bar_chart_rounded,
            )
          else ...[
            const Text(
              'Spending by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 58,
                      sectionsSpace: 3,
                      startDegreeOffset: -90,
                      sections: categoryTotals.entries.map((entry) {
                        return PieChartSectionData(
                          value: entry.value,
                          color: CategoryIcon.getColor(entry.key),
                          radius: 38,
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                  ),

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyUtils.format(total, currency: currency),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Total',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            ...categoryTotals.entries.map((entry) {
              final percentage = total == 0 ? 0 : (entry.value / total) * 100;

              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: CategoryIcon.getColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(child: Text(entry.key)),

                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(width: 15),

                    SizedBox(
                      width: 85,
                      child: Text(
                        CurrencyUtils.format(entry.value, currency: currency),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    context,
                    '${expenses.length}',
                    'Transactions',
                    Icons.receipt_long_rounded,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _statCard(
                    context,
                    CurrencyUtils.format(average, currency: currency),
                    'Average',
                    Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),

          const SizedBox(height: 8),

          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),

          const SizedBox(height: 3),

          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
