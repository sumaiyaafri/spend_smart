import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/models/recurring_expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';

class RecurringExpensesScreen extends StatelessWidget {
  const RecurringExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final currency = context.read<SettingsProvider>().currency;
    return Scaffold(
      backgroundColor: context.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                children: [
                  _introCard(context),
                  const SizedBox(height: 16),
                  if (provider.recurringExpenses.isEmpty)
                    _emptyState(context)
                  else
                    ...provider.recurringExpenses.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _recurringCard(context, provider, item, currency),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add recurring'),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 20, 8),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17)),
        const Expanded(child: Center(child: Text('Recurring Expenses', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 48),
      ]),
    );
  }

  Widget _introCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF078B67), Color(0xFF04684E)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .16), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: const Row(children: [
        Icon(Icons.autorenew_rounded, color: Colors.white, size: 28),
        SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Never miss a monthly payment', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          SizedBox(height: 3),
          Text('Get a reminder 3 days before and confirm payment on the due date.', style: TextStyle(color: Colors.white70, fontSize: 9)),
        ])),
      ]),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(17), border: Border.all(color: context.outlineColor)),
      child: Column(children: [
        Icon(Icons.event_repeat_rounded, size: 34, color: context.secondaryTextColor),
        const SizedBox(height: 9),
        const Text('No recurring expenses yet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Add rent, subscriptions, tuition or any monthly payment.', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: context.secondaryTextColor)),
      ]),
    );
  }

  Widget _recurringCard(BuildContext context, ExpenseProvider provider, RecurringExpense item, String currency) {
    final paid = provider.isRecurringPaid(item);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(17), border: Border.all(color: context.outlineColor)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.event_repeat_rounded, color: AppColors.orange, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('${item.category} • Every month on ${item.dueDay}${_ordinal(item.dueDay)}', style: TextStyle(fontSize: 8, color: context.secondaryTextColor)),
          const SizedBox(height: 5),
          Text(CurrencyUtils.format(item.amount, currency: currency), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: (paid ? AppColors.primary : AppColors.orange).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(paid ? 'Paid' : 'Due', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: paid ? AppColors.primary : AppColors.orange))),
          const SizedBox(height: 5),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert_rounded, size: 18, color: context.secondaryTextColor),
            onSelected: (value) async {
              if (value == 'edit') {
                await _showEditor(context, item);
                return;
              }
              if (value == 'paid') {
                if (!context.mounted) return;
                await _markPaid(context, provider, item);
                return;
              }
              if (value == 'delete') await provider.deleteRecurringExpense(item);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit recurring expense')),
              if (!paid) const PopupMenuItem(value: 'paid', child: Text('Mark paid this month')),
              const PopupMenuItem(value: 'delete', child: Text('Delete recurring expense')),
            ],
          ),
        ]),
      ]),
    );
  }

  Future<void> _showEditor(BuildContext context, [RecurringExpense? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RecurringExpenseEditor(existing: existing),
    );
    if (saved == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existing == null ? 'Recurring expense added' : 'Recurring expense updated')));
  }

  Future<void> _markPaid(BuildContext context, ExpenseProvider provider, RecurringExpense item) async {
    final selected = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(DateTime.now().year, DateTime.now().month, 1), lastDate: DateTime.now());
    if (selected != null) await provider.markRecurringPaid(item, selected);
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
}

class _RecurringExpenseEditor extends StatefulWidget {
  final RecurringExpense? existing;

  const _RecurringExpenseEditor({this.existing});

  @override
  State<_RecurringExpenseEditor> createState() => _RecurringExpenseEditorState();
}

class _RecurringExpenseEditorState extends State<_RecurringExpenseEditor> {
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  late final TextEditingController categoryController;
  int dueDay = DateTime.now().day;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    titleController = TextEditingController(text: existing?.title ?? '');
    amountController = TextEditingController(text: existing == null ? '' : existing.amount.toStringAsFixed(0));
    categoryController = TextEditingController(text: existing?.category ?? 'Bills');
    dueDay = existing?.dueDay ?? DateTime.now().day;
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.existing == null ? 'Add recurring expense' : 'Edit recurring expense', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _field(titleController, 'Title', 'e.g. ChatGPT plan'),
          const SizedBox(height: 9),
          _field(amountController, 'Amount', '৳ 0', keyboard: TextInputType.number),
          const SizedBox(height: 9),
          _field(categoryController, 'Category', 'e.g. Bills'),
          const SizedBox(height: 9),
          InkWell(
            onTap: _pickDueDay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(color: context.fieldColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.outlineColor)),
              child: Row(children: [const Icon(Icons.calendar_month_rounded, size: 17, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text('Payment day: $dueDay${_ordinal(dueDay)} of every month', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))), const Icon(Icons.chevron_right_rounded, size: 18)]),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 44, child: FilledButton(onPressed: _save, child: Text(widget.existing == null ? 'Save recurring expense' : 'Save changes'))),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint, {TextInputType? keyboard}) {
    return TextField(controller: controller, keyboardType: keyboard, decoration: InputDecoration(labelText: label, hintText: hint));
  }

  Future<void> _pickDueDay() async {
    final now = DateTime.now();
    final selected = await showDatePicker(context: context, initialDate: DateTime(now.year, now.month, dueDay.clamp(1, 28).toInt()), firstDate: DateTime(now.year, now.month, 1), lastDate: DateTime(now.year + 2));
    if (selected != null && mounted) setState(() => dueDay = selected.day);
  }

  Future<void> _save() async {
    final value = double.tryParse(amountController.text.trim());
    if (titleController.text.trim().isEmpty || value == null || value <= 0) return;
    final existing = widget.existing;
    await context.read<ExpenseProvider>().saveRecurringExpense(RecurringExpense(id: existing?.id, title: titleController.text.trim(), amount: value, category: categoryController.text.trim().isEmpty ? 'Bills' : categoryController.text.trim(), dueDay: dueDay, active: existing?.active ?? true, createdAt: existing?.createdAt));
    if (mounted) Navigator.pop(context, true);
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
}
