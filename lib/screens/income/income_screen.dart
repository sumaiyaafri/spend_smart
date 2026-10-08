import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/income.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/empty_state.dart';
import 'add_income_redesign.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});
  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  static IconData sourceIcon(String source) => switch (source) {
    'Salary' => Icons.work_rounded,
    'Bonus' => Icons.stars_rounded,
    'Gift' => Icons.card_giftcard_rounded,
    'Freelance' => Icons.laptop_mac_rounded,
    _ => Icons.payments_rounded,
  };

  Future<void> _delete(Income income) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete income?'),
        content: Text('Remove "${income.title}" from your records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || income.id == null) return;
    try {
      await context.read<ExpenseProvider>().deleteIncome(income.id!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete income. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<ExpenseProvider>();
    final currency = context.watch<SettingsProvider>().currency;
    String money(double amount) =>
        CurrencyUtils.format(amount, currency: currency);
    bool inMonth(DateTime date) =>
        date.year == _month.year && date.month == _month.month;
    final records = data.incomes
        .where((income) => inMonth(income.date))
        .toList();
    final received = records.fold<double>(
      0,
      (sum, income) => sum + income.amount,
    );
    final spent = data.expenses
        .where((expense) => inMonth(expense.date))
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Income & balance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add income'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      ),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        AppDateUtils.formatMonthYear(_month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _month.year == DateTime.now().year &&
                              _month.month == DateTime.now().month
                          ? null
                          : () => setState(
                              () => _month = DateTime(
                                _month.year,
                                _month.month + 1,
                              ),
                            ),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Income this month: ${money(received)}'),
                        const SizedBox(height: 10),
                        Text('Expenses this month: ${money(spent)}'),
                        const SizedBox(height: 10),
                        Text(
                          'Net this month: ${money(received - spent)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Divider(height: 28),
                        Text(
                          'Balance from all recorded entries: ${money(data.balance)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Money received',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (data.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (data.error != null) ...[
                  const Text('Could not load your records.'),
                  TextButton(
                    onPressed: data.loadExpenses,
                    child: const Text('Retry'),
                  ),
                ] else if (records.isEmpty)
                  const EmptyState(
                    title: 'No income recorded',
                    message:
                        'Add your salary, a bonus, a gift or any money received this month.',
                    icon: Icons.savings_outlined,
                  )
                else
                  ...records.map(
                    (income) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  sourceIcon(income.source),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    income.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Income actions',
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AddIncomeScreen(income: income),
                                        ),
                                      );
                                    } else {
                                      _delete(income);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              '+ ${money(income.amount)}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${income.source} • ${AppDateUtils.formatDate(income.date)}',
                            ),
                            if (income.note?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(income.note!),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
