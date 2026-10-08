import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  late String _source;
  bool _saving = false;
  static const sources = ['Salary', 'Bonus', 'Gift', 'Freelance', 'Other'];

  @override
  void initState() {
    super.initState();
    final income = widget.income;
    _title = TextEditingController(text: income?.title ?? '');
    _amount = TextEditingController(text: income?.amount.toString() ?? '');
    _note = TextEditingController(text: income?.note ?? '');
    _source = income?.source ?? 'Salary';
    _date = income?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<ExpenseProvider>().saveIncome(
        Income(
          id: widget.income?.id,
          title: _title.text.trim(),
          amount: double.parse(_amount.text.trim()),
          source: _source,
          date: _date,
          note: _note.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save income. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.income == null ? 'Add income' : 'Edit income'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Record money you have received, including monthly salary or unexpected income.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Income title',
                    hintText: 'e.g. October salary or birthday gift',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an income title'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount received',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || !amount.isFinite || amount <= 0
                        ? 'Enter a valid amount greater than zero'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _source,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Income source'),
                  items: sources
                      .map(
                        (source) => DropdownMenuItem(
                          value: source,
                          child: Text(source),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _source = value!),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null && mounted) {
                            setState(() => _date = date);
                          }
                        },
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text('Received: ${AppDateUtils.formatDate(_date)}'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Saving…' : 'Save income'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
