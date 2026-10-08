import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/expense.dart';
import '../../data/models/income.dart';
import '../../providers/expense_provider.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool working = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    return Scaffold(
      backgroundColor: context.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                children: [
                  _introCard(),
                  const SizedBox(height: 14),
                  _actionCard(
                    icon: Icons.upload_rounded,
                    color: AppColors.primary,
                    title: 'Export your data',
                    subtitle: '${provider.expenses.length} expenses • ${provider.incomes.length} income records',
                    button: 'Export JSON',
                    onTap: working ? null : _exportBackup,
                  ),
                  const SizedBox(height: 10),
                  _actionCard(
                    icon: Icons.download_rounded,
                    color: AppColors.blue,
                    title: 'Restore a backup',
                    subtitle: 'Add records from a Spend Smart JSON backup',
                    button: 'Choose file',
                    onTap: working ? null : _restoreBackup,
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: context.isDarkMode ? const Color(0xFF332B18) : const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(14)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, size: 17, color: AppColors.orange), const SizedBox(width: 8), Expanded(child: Text('Restore adds records to your current data. It does not delete anything, so you can safely move data between devices.', style: TextStyle(fontSize: 9, color: context.primaryTextColor)))]),
                  ),
                  if (working) ...[const SizedBox(height: 20), const Center(child: CircularProgressIndicator())],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 20, 8),
      child: Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17)), const Expanded(child: Center(child: Text('Backup & Restore', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))), const SizedBox(width: 48)]),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF078B67), Color(0xFF04684E)]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .16), blurRadius: 14, offset: const Offset(0, 6))]),
      child: const Row(children: [Icon(Icons.shield_outlined, color: Colors.white, size: 28), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your data stays yours', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Create a portable backup of your expenses and income.', style: TextStyle(color: Colors.white70, fontSize: 9))]))]),
    );
  }

  Widget _actionCard({required IconData icon, required Color color, required String title, required String subtitle, required String button, required VoidCallback? onTap}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.outlineColor)),
      child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 19, color: color)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: TextStyle(fontSize: 8, color: context.secondaryTextColor))])), FilledButton.tonal(onPressed: onTap, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap), child: Text(button, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)))],),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => working = true);
    try {
      final provider = context.read<ExpenseProvider>();
      final payload = {
        'app': 'Spend Smart',
        'formatVersion': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'expenses': provider.expenses.map((expense) => expense.toMap()).toList(),
        'incomes': provider.incomes.map((income) => income.toMap()).toList(),
      };
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));
      final path = await FilePicker.saveFile(dialogTitle: 'Save Spend Smart backup', fileName: 'spend_smart_backup.json', type: FileType.custom, allowedExtensions: ['json'], bytes: bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path == null ? 'Export cancelled' : 'Backup saved successfully')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _restoreBackup() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (file == null || !mounted) return;
    final shouldRestore = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Restore backup?'), content: const Text('Records from this JSON file will be added to your current data. Existing records will not be deleted.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore'))])) ?? false;
    if (!shouldRestore || !mounted) return;
    setState(() => working = true);
    final provider = context.read<ExpenseProvider>();
    try {
      final bytes = await file.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['app'] != 'Spend Smart' || decoded['formatVersion'] != 1) throw const FormatException('This is not a valid Spend Smart backup');
      final expenseItems = decoded['expenses'];
      final incomeItems = decoded['incomes'];
      if ((expenseItems != null && expenseItems is! List) || (incomeItems != null && incomeItems is! List)) {
        throw const FormatException('Backup records are not formatted correctly');
      }
      final expenses = (expenseItems as List? ?? []).map((item) {
        if (item is! Map) throw const FormatException('Invalid expense record');
        return Expense.fromMap(Map<String, dynamic>.from(item));
      }).toList();
      final incomes = (incomeItems as List? ?? []).map((item) {
        if (item is! Map) throw const FormatException('Invalid income record');
        return Income.fromMap(Map<String, Object?>.from(item));
      }).toList();
      await provider.restoreBackup(expenses: expenses, incomes: incomes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored ${expenses.length} expenses and ${incomes.length} income records')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $error')));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }
}
