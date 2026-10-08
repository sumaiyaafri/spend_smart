import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/expense_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/category_icon.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;

  const AddExpenseScreen({super.key, this.expense});

  bool get isEditing => expense != null;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  late final TextEditingController noteController;

  String selectedCategory = 'Food & Dining';
  DateTime selectedDate = DateTime.now();
  bool isSaving = false;
  // Tags are currently presentation-only because Expense has no tags field yet.
  final tags = <String>['office', 'friends'];

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    titleController = TextEditingController(text: expense?.title ?? '');
    amountController = TextEditingController(
      text: expense == null
          ? ''
          : expense.amount.toStringAsFixed(expense.amount % 1 == 0 ? 0 : 2),
    );
    noteController = TextEditingController(text: expense?.note ?? '');
    selectedCategory = expense?.category ?? selectedCategory;
    selectedDate = expense?.date ?? selectedDate;
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
      lastDate: DateTime(2100),
    );
    if (result == null) return;
    setState(() {
      selectedDate = DateTime(
        result.year,
        result.month,
        result.day,
        selectedDate.hour,
        selectedDate.minute,
      );
    });
  }

  Future<void> pickCategory() async {
    final category = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: ExpenseCategories.all
              .map(
                (item) => ListTile(
                  leading: CategoryIcon(category: item, size: 36),
                  title: Text(item),
                  trailing: item == selectedCategory
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, item),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (category != null) setState(() => selectedCategory = category);
  }

  Future<void> saveExpense() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => isSaving = true);
    try {
      final oldExpense = widget.expense;
      final expense = Expense(
        id: oldExpense?.id,
        title: titleController.text.trim(),
        amount: amount,
        category: selectedCategory,
        date: selectedDate,
        note: noteController.text.trim(),
        createdAt: oldExpense?.createdAt,
      );
      final provider = context.read<ExpenseProvider>();
      if (widget.isEditing) {
        await provider.updateExpense(expense);
      } else {
        await provider.addExpense(expense);
      }
      if (mounted) Navigator.pop(context, true);
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
                    _fieldLabel('Title'),
                    _textField(controller: titleController, hint: 'Lunch', validator: (value) => value == null || value.trim().isEmpty ? 'Enter a title' : null),
                    const SizedBox(height: 12),
                    _fieldLabel('Amount'),
                    _textField(controller: amountController, hint: '250', prefix: '৳ ', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (value) => double.tryParse(value?.trim() ?? '') == null ? 'Enter a valid amount' : null),
                    const SizedBox(height: 7),
                    _amountShortcuts(),
                    const SizedBox(height: 13),
                    _fieldLabel('Category'),
                    _categoryField(),
                    const SizedBox(height: 12),
                    _fieldLabel('Date'),
                    _dateField(),
                    const SizedBox(height: 12),
                    _fieldLabel('Notes (optional)'),
                    _textField(controller: noteController, hint: 'With friends', maxLines: 1),
                    const SizedBox(height: 12),
                    _fieldLabel('Tags (optional)'),
                    _tagsField(),
                    const SizedBox(height: 12),
                    _receiptSection(),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSaving ? null : saveExpense,
                        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(widget.isEditing ? 'Update Expense' : 'Save Expense', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
          const Expanded(child: Center(child: Text('Add Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 3, bottom: 5),
          child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: context.secondaryTextColor)),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    String? prefix,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
    return Row(
      children: [50, 100, 200, 500]
          .map(
            (amount) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => setState(() => amountController.text = amount.toString()),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFFEAF2F0), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('$amount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _categoryField() {
    return InkWell(
      onTap: pickCategory,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(color: context.fieldColor, borderRadius: BorderRadius.circular(11), border: Border.all(color: context.outlineColor)),
        child: Row(
          children: [
            CategoryIcon(category: selectedCategory, size: 34),
            const SizedBox(width: 8),
            Expanded(child: Text(selectedCategory, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right_rounded, size: 19, color: context.secondaryTextColor),
          ],
        ),
      ),
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

  Widget _tagsField() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...tags.map((tag) => _tagChip(tag)),
        InkWell(
          onTap: () => setState(() => tags.add('tag ${tags.length + 1}')),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: context.fieldColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.outlineColor)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 13, color: AppColors.primary), SizedBox(width: 3), Text('Add', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700))]),
          ),
        ),
      ],
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 5, top: 5, bottom: 5),
      decoration: BoxDecoration(color: const Color(0xFFE2F1EC), borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => setState(() => tags.remove(tag)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text(tag, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)), const SizedBox(width: 4), const Icon(Icons.close_rounded, size: 12)]),
      ),
    );
  }

  Widget _receiptSection() {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt attachment coming soon'))),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.camera_alt_outlined, size: 15, color: context.secondaryTextColor), const SizedBox(width: 5), Text('Add Receipt Photo', style: TextStyle(fontSize: 10, color: context.secondaryTextColor, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 7),
          Row(children: [Container(width: 45, height: 45, decoration: BoxDecoration(color: context.mutedSurfaceColor, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.photo_camera_back_outlined, size: 20, color: context.secondaryTextColor)), const SizedBox(width: 8), Container(width: 45, height: 45, decoration: BoxDecoration(color: context.softGreenColor, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_rounded, color: AppColors.primary))]),
        ],
      ),
    );
  }
}
