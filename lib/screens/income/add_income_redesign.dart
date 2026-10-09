import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/income.dart';
import '../../providers/expense_provider.dart';

class AddIncomeScreen extends StatefulWidget {
  final Income? income;

  const AddIncomeScreen({super.key, this.income});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  late final TextEditingController noteController;

  static const sources = ['Salary', 'Bonus', 'Gift', 'Freelance', 'Other'];
  String selectedSource = 'Salary';
  DateTime selectedDate = DateTime.now();
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final income = widget.income;
    titleController = TextEditingController(text: income?.title ?? '');
    amountController = TextEditingController(
      text: income == null
          ? ''
          : income.amount.toStringAsFixed(income.amount % 1 == 0 ? 0 : 2),
    );
    noteController = TextEditingController(text: income?.note ?? '');
    selectedSource = income?.source ?? selectedSource;
    selectedDate = income?.date ?? selectedDate;
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  String get dateLabel {
    final formatted = AppDateUtils.formatDate(selectedDate);
    return AppDateUtils.isSameDay(selectedDate, DateTime.now())
        ? 'Today, $formatted'
        : formatted;
  }

  Future<void> pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (result == null) return;
    setState(() => selectedDate = result);
  }

  Future<void> pickSource() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: sources
              .map(
                (item) => ListTile(
                  leading: _sourceIcon(item),
                  title: Text(item),
                  trailing: item == selectedSource
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, item),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (source != null) setState(() => selectedSource = source);
  }

  Future<void> saveIncome() async {
    if (isSaving || !(formKey.currentState?.validate() ?? false)) return;
    setState(() => isSaving = true);
    try {
      await context.read<ExpenseProvider>().saveIncome(
            Income(
              id: widget.income?.id,
              title: titleController.text.trim(),
              amount: double.parse(amountController.text.trim()),
              source: selectedSource,
              date: selectedDate,
              note: noteController.text.trim(),
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save income. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBackground,
      body: SafeArea(
        child: Form(
          key: formKey,
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
                  children: [
                    _label('Title'),
                    _textField(controller: titleController, hint: 'Salary', validator: (value) => value == null || value.trim().isEmpty ? 'Enter an income title' : null),
                    const SizedBox(height: 12),
                    _label('Amount'),
                    _textField(controller: amountController, hint: '24,000', prefix: '৳ ', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      return amount == null || !amount.isFinite || amount <= 0 ? 'Enter a valid amount' : null;
                    }),
                    const SizedBox(height: 7),
                    _amountShortcuts(),
                    const SizedBox(height: 13),
                    _label('Category'),
                    _sourceField(),
                    const SizedBox(height: 12),
                    _label('Date'),
                    _dateField(),
                    const SizedBox(height: 12),
                    _label('Notes (optional)'),
                    _textField(controller: noteController, hint: 'Monthly salary', minLines: 3, maxLines: 5),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: isSaving ? null : saveIncome,
                        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.income == null ? 'Save Income' : 'Update Income', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          Expanded(child: Center(child: Text(widget.income == null ? 'Add Income' : 'Edit Income', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 3, bottom: 5),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: context.secondaryTextColor)),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    String? prefix,
    int? minLines,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        hintStyle: TextStyle(fontSize: 11, color: context.secondaryTextColor),
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        filled: true,
        fillColor: context.fieldColor,
        errorStyle: const TextStyle(fontSize: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: context.outlineColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: context.outlineColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.primary, width: 1.2)),
      ),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  Widget _amountShortcuts() {
    const values = [(5000, '5K'), (10000, '10K'), (20000, '20K'), (50000, '50K')];
    return Row(
      children: values
          .map(
            (value) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => setState(() => amountController.text = value.$1.toString()),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(color: context.mutedSurfaceColor, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(value.$2, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: context.primaryTextColor))),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _sourceField() {
    return InkWell(
      onTap: pickSource,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(color: context.fieldColor, borderRadius: BorderRadius.circular(11), border: Border.all(color: context.outlineColor)),
        child: Row(
          children: [
            _sourceIcon(selectedSource),
            const SizedBox(width: 8),
            Expanded(child: Text(selectedSource, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right_rounded, size: 19, color: context.secondaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _sourceIcon(String source) {
    final (icon, color) = switch (source) {
      'Salary' => (Icons.account_balance_wallet_rounded, const Color(0xFF3B82D0)),
      'Bonus' => (Icons.emoji_events_rounded, const Color(0xFFE79A28)),
      'Gift' => (Icons.card_giftcard_rounded, const Color(0xFFE85B9A)),
      'Freelance' => (Icons.work_rounded, const Color(0xFF8B72F6)),
      _ => (Icons.payments_rounded, AppColors.primary),
    };

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Color.lerp(context.fieldColor, color, context.isDarkMode ? .3 : .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: pickDate,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 43,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(color: context.fieldColor, borderRadius: BorderRadius.circular(11), border: Border.all(color: context.outlineColor)),
        child: Row(
          children: [
            Expanded(child: Text(dateLabel, style: TextStyle(fontSize: 11, color: context.secondaryTextColor))),
            const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primaryDark),
          ],
        ),
      ),
    );
  }

}
