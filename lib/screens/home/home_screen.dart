import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/summary_card.dart';
import '../expense_details/expense_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good Morning';
    }

    if (hour < 17) {
      return 'Good Afternoon';
    }

    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();

    final settingsProvider = context.watch<SettingsProvider>();

    final currency = settingsProvider.currency;

    final recentExpenses = expenseProvider.expenses.take(5).toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: expenseProvider.loadExpenses,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            Text(
              '${_greeting()},',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 3),

            const Text(
              'Spend Smart 👋',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 5),

            Text(
              AppDateUtils.formatDateWithDay(DateTime.now()),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 26),

            SummaryCard(
              title: "Today's Spending",
              amount: CurrencyUtils.format(
                expenseProvider.todayTotal,
                currency: currency,
              ),
              subtitle: '${expenseProvider.todayExpenses.length} transactions',
              icon: Icons.account_balance_wallet_rounded,
              primary: true,
            ),

            const SizedBox(height: 14),

            SummaryCard(
              title: 'This Month',
              amount: CurrencyUtils.format(
                expenseProvider.monthTotal,
                currency: currency,
              ),
              subtitle:
                  '${expenseProvider.currentMonthExpenses.length} transactions',
              icon: Icons.calendar_month_rounded,
            ),

            const SizedBox(height: 30),

            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Text(
                  'Recent Expenses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),

                Text(
                  '${expenseProvider.expenses.length} total',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (expenseProvider.isLoading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (recentExpenses.isEmpty)
              const EmptyState(
                title: 'No expenses yet',
                message: 'Tap the + button and add your first expense.',
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: recentExpenses
                      .map(
                        (expense) => ExpenseTile(
                          expense: expense,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExpenseDetailsScreen(expense: expense),
                              ),
                            );
                          },
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
}
