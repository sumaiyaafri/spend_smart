import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
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
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool showHistory = false;
  String search = '';
  String? sourceFilter;

  static IconData sourceIcon(String source) => switch (source) {
        'Salary' => Icons.work_rounded,
        'Bonus' => Icons.stars_rounded,
        'Gift' => Icons.card_giftcard_rounded,
        'Freelance' => Icons.laptop_mac_rounded,
        _ => Icons.payments_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;
    final records = provider.incomes.where((income) => income.date.year == selectedMonth.year && income.date.month == selectedMonth.month).toList();
    final filterIsAvailable = sourceFilter != null && records.any((income) => income.source == sourceFilter);
    final visibleRecords = !filterIsAvailable ? records : records.where((income) => income.source == sourceFilter).toList();
    final received = records.fold<double>(0, (sum, income) => sum + income.amount);
    final spent = provider.expenses.where((expense) => expense.date.year == selectedMonth.year && expense.date.month == selectedMonth.month).fold<double>(0, (sum, expense) => sum + expense.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
                children: [
                  _viewToggle(),
                  const SizedBox(height: 12),
                  if (showHistory)
                    _historyView(provider, currency)
                  else ...[
                    _monthPicker(),
                    const SizedBox(height: 14),
                    _summaryCard(received, spent, provider.balance, currency),
                    const SizedBox(height: 20),
                    _sourceFilters(records),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          filterIsAvailable ? '$sourceFilter income' : 'Money received',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        TextButton(
                          onPressed: () => setState(() => showHistory = true),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(72, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: const Text('View history', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    if (provider.isLoading)
                      const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                    else if (provider.error != null)
                      _errorState(provider)
                    else if (visibleRecords.isEmpty)
                      const EmptyState(title: 'No income recorded', message: 'Add your salary, bonus, gift or any money received this month.', icon: Icons.savings_outlined)
                    else
                      ...visibleRecords.map((income) => _incomeCard(income, currency)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'income-add-income',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddIncomeScreen())),
        backgroundColor: const Color(0xFF71E5BE),
        foregroundColor: AppColors.primaryDark,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add income', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _viewToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF0F5F3), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: _viewButton('Overview', !showHistory)),
        Expanded(child: _viewButton('Income History', showHistory)),
      ]),
    );
  }

  Widget _viewButton(String label, bool selected) {
    return InkWell(
      onTap: () => setState(() => showHistory = label == 'Income History'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _historyView(ExpenseProvider provider, String currency) {
    final query = search.trim().toLowerCase();
    final records = provider.incomes.where((income) => query.isEmpty || income.title.toLowerCase().contains(query) || income.source.toLowerCase().contains(query) || (income.note ?? '').toLowerCase().contains(query)).toList()..sort((a, b) => b.date.compareTo(a.date));
    final total = records.fold<double>(0, (sum, income) => sum + income.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (value) => setState(() => search = value),
          style: const TextStyle(fontSize: 10),
          decoration: InputDecoration(
            hintText: 'Search income history...',
            hintStyle: const TextStyle(fontSize: 10),
            prefixIcon: const Icon(Icons.search_rounded, size: 17),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('All income records', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), Text(CurrencyUtils.format(total, currency: currency), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark))]),
        const SizedBox(height: 9),
        if (records.isEmpty)
          const EmptyState(title: 'No income history', message: 'Your income records will appear here.', icon: Icons.history_rounded)
        else
          ...records.map((income) => _incomeCard(income, currency)),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 20, 8),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17)),
          const Expanded(child: Center(child: Text('Income & balance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _monthPicker() {
    final canGoNext = selectedMonth.isBefore(DateTime(DateTime.now().year, DateTime.now().month));
    return Row(
      children: [
        IconButton(onPressed: () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1)), icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary)),
        Expanded(child: Text(AppDateUtils.formatMonthYear(selectedMonth), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
        IconButton(onPressed: canGoNext ? () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1)) : null, icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _summaryCard(double received, double spent, double balance, String currency) {
    final net = received - spent;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF078B67), Color(0xFF04684E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .16), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Income this month', style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 10)),
                    const SizedBox(height: 3),
                    Text(CurrencyUtils.format(received, currency: currency), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(net >= 0 ? 'You are ahead by ${CurrencyUtils.format(net, currency: currency)}' : 'Spending is higher than income', style: TextStyle(color: Colors.white.withValues(alpha: .76), fontSize: 9)),
                  ],
                ),
              ),
              Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), shape: BoxShape.circle), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 23)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _summaryMetric('Expenses', CurrencyUtils.format(spent, currency: currency), AppColors.orange),
            const SizedBox(width: 8),
            _summaryMetric('Net', CurrencyUtils.format(net, currency: currency), net >= 0 ? AppColors.primary : AppColors.red),
            const SizedBox(width: 8),
            _summaryMetric('All-time balance', CurrencyUtils.format(balance, currency: currency), AppColors.blue),
          ],
        ),
      ],
    );
  }

  Widget _summaryMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(height: 5),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _sourceFilters(List<Income> records) {
    final sources = records.map((income) => income.source).toSet().toList();
    if (sources.length < 2) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(label: const Text('All', style: TextStyle(fontSize: 9)), selected: sourceFilter == null, showCheckmark: false, selectedColor: AppColors.primary, labelStyle: TextStyle(color: sourceFilter == null ? Colors.white : AppColors.textSecondary), onSelected: (_) => setState(() => sourceFilter = null)),
          const SizedBox(width: 6),
          ...sources.map(
            (source) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: Text(source, style: const TextStyle(fontSize: 9)), selected: sourceFilter == source, showCheckmark: false, selectedColor: AppColors.primary, labelStyle: TextStyle(color: sourceFilter == source ? Colors.white : AppColors.textSecondary), onSelected: (_) => setState(() => sourceFilter = source)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomeCard(Income income, String currency) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(11)), child: Icon(sourceIcon(income.source), size: 18, color: AppColors.primaryDark)), const SizedBox(width: 9), Expanded(child: Text(income.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))), PopupMenuButton<String>(padding: EdgeInsets.zero, iconSize: 19, onSelected: (action) { if (action == 'edit') { Navigator.push(context, MaterialPageRoute(builder: (_) => AddIncomeScreen(income: income))); } else { _delete(income); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))])]), const SizedBox(height: 6), Text('+ ${CurrencyUtils.format(income.amount, currency: currency)}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${income.source} • ${AppDateUtils.formatDate(income.date)}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)), if (income.note?.isNotEmpty == true) ...[const SizedBox(height: 4), Text(income.note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary))]]),
    );
  }

  Widget _errorState(ExpenseProvider provider) {
    return Column(children: [const Text('Could not load your records.', style: TextStyle(fontSize: 11)), TextButton(onPressed: provider.loadExpenses, child: const Text('Retry'))]);
  }

  Future<void> _delete(Income income) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete income?'), content: Text('Remove "${income.title}" from your records?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (confirmed != true || !mounted || income.id == null) return;
    try {
      await context.read<ExpenseProvider>().deleteIncome(income.id!);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete income. Please try again.')));
    }
  }
}
