import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/expense_categories.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/custom_text_field.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;

  const AddExpenseScreen({super.key, this.expense});

  bool get isEditing => expense != null;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController titleController;

  late final TextEditingController amountController;

  late final TextEditingController noteController;

  late TextEditingController dateController;

  String selectedCategory = 'Food & Dining';

  DateTime selectedDate = DateTime.now();

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    final expense = widget.expense;

    titleController = TextEditingController(text: expense?.title ?? '');

    amountController = TextEditingController(
      text: expense != null
          ? expense.amount.toStringAsFixed(expense.amount % 1 == 0 ? 0 : 2)
          : '',
    );

    noteController = TextEditingController(text: expense?.note ?? '');

    if (expense != null) {
      selectedCategory = expense.category;

      selectedDate = expense.date;
    }

    dateController = TextEditingController(
      text: AppDateUtils.formatDate(selectedDate),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    dateController.dispose();

    super.dispose();
  }

  Future<void> _pickDate() async {
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

      dateController.text = AppDateUtils.formatDate(selectedDate);
    });
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(amountController.text.trim());

    if (amount == null || amount <= 0) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final existing = widget.expense;

      final expense = Expense(
        id: existing?.id,
        title: titleController.text.trim(),
        amount: amount,
        category: selectedCategory,
        date: selectedDate,
        note: noteController.text.trim(),
        createdAt: existing?.createdAt,
      );

      final provider = context.read<ExpenseProvider>();

      if (widget.isEditing) {
        await provider.updateExpense(expense);
      } else {
        await provider.addExpense(expense);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Expense' : 'Add Expense'),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CustomTextField(
                controller: titleController,
                label: 'Title',
                icon: Icons.receipt_long_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter expense title';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              CustomTextField(
                controller: amountController,
                label: 'Amount',
                icon: Icons.payments_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');

                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: ExpenseCategories.all
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            CategoryIcon(category: category, size: 34),
                            const SizedBox(width: 10),
                            Text(category),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),

              const SizedBox(height: 14),

              CustomTextField(
                controller: dateController,
                label: 'Date',
                icon: Icons.calendar_month_rounded,
                readOnly: true,
                onTap: _pickDate,
              ),

              const SizedBox(height: 14),

              CustomTextField(
                controller: noteController,
                label: 'Note (Optional)',
                icon: Icons.notes_rounded,
                maxLines: 4,
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: isSaving ? null : _saveExpense,
                child: isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isEditing ? 'Update Expense' : 'Save Expense',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
