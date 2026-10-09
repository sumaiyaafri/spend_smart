import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/expense.dart';
import '../../data/models/income.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/statement_pdf_service.dart';
import '../../widgets/category_icon.dart';

class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  int selectedPreset = 0;
  DateTimeRange? customRange;

  DateTimeRange get range {
    final now = DateTime.now();
    switch (selectedPreset) {
      case 1:
        return DateTimeRange(start: DateTime(now.year, now.month - 1, 1), end: DateTime(now.year, now.month, 0, 23, 59, 59));
      case 2:
        return DateTimeRange(start: DateTime(now.year, now.month - 2, 1), end: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case 3:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31, 23, 59, 59));
      case 4:
        return customRange ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      default:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final currency = context.watch<SettingsProvider>().currency;
    final expenses = provider.expenses.where((item) => _inRange(item.date)).toList()..sort((a, b) => b.date.compareTo(a.date));
    final incomes = provider.incomes.where((item) => _inRange(item.date)).toList()..sort((a, b) => b.date.compareTo(a.date));
    final totalIncome = incomes.fold<double>(0, (sum, item) => sum + item.amount);
    final totalExpenses = expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final opening = _openingBalance(provider);
    final closing = opening + totalIncome - totalExpenses;
    final elapsedDays = AppDateUtils.elapsedDaysInRange(
      range.start,
      range.end,
    );
    final dailyAverage = elapsedDays == 0 ? 0.0 : totalExpenses / elapsedDays;
    final categories = _categoryTotals(expenses);

    return Scaffold(
      backgroundColor: context.pageBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 30),
          children: [
            _topBar(context),
            const SizedBox(height: 13),
            _periodPicker(context),
            const SizedBox(height: 10),
            _periodTabs(context),
            const SizedBox(height: 14),
            _summaryGrid(totalIncome, totalExpenses, closing, dailyAverage, incomes.length, expenses.length, currency),
            const SizedBox(height: 14),
            _chartsCard(expenses, incomes, categories, totalExpenses, currency),
            const SizedBox(height: 14),
            _transactionCard(expenses, incomes, currency),
            const SizedBox(height: 14),
            _closingCard(opening, totalIncome, totalExpenses, closing, currency),
          ],
        ),
      ),
    );
  }

  bool _inRange(DateTime date) => !date.isBefore(range.start) && !date.isAfter(range.end);

  double _openingBalance(ExpenseProvider provider) {
    var income = 0.0;
    var expenses = 0.0;
    for (final item in provider.incomes) {
      if (item.date.isBefore(range.start)) income += item.amount;
    }
    for (final item in provider.expenses) {
      if (item.date.isBefore(range.start)) expenses += item.amount;
    }
    return income - expenses;
  }

  Map<String, double> _categoryTotals(List<Expense> expenses) {
    final totals = <String, double>{};
    for (final item in expenses) {
      totals.update(item.category, (value) => value + item.amount, ifAbsent: () => item.amount);
    }
    return totals;
  }

  Widget _topBar(BuildContext context) {
    return Row(children: [
      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18)),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Statement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 2), Text('Income & Expense Statement', style: TextStyle(fontSize: 10))])),
      _headerButton(Icons.download_rounded, 'Export', _exportStatement),
      const SizedBox(width: 7),
      _headerButton(Icons.tune_rounded, 'Filter', () => _showFilter(context)),
    ]);
  }

  Widget _headerButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(13), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), decoration: BoxDecoration(color: context.mutedSurfaceColor, borderRadius: BorderRadius.circular(13)), child: Column(children: [Icon(icon, size: 18, color: AppColors.primary), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700))])));
  }

  Widget _periodPicker(BuildContext context) {
    final label = selectedPreset == 4 ? '${AppDateUtils.formatDate(range.start)} – ${AppDateUtils.formatDate(range.end)}' : selectedPreset == 0 ? AppDateUtils.formatMonthYear(DateTime.now()) : ['This Month', 'Last Month', 'Last 3 Months', 'This Year', 'Custom Range'][selectedPreset];
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9), decoration: BoxDecoration(color: context.mutedSurfaceColor, borderRadius: BorderRadius.circular(14)), child: Row(children: [IconButton(onPressed: _previousPreset, icon: const Icon(Icons.chevron_left_rounded, size: 20)), Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))), IconButton(onPressed: _nextPreset, icon: const Icon(Icons.chevron_right_rounded, size: 20))]));
  }

  Widget _periodTabs(BuildContext context) {
    const labels = ['This Month', 'Last Month', 'Last 3 Months', 'This Year', 'Custom Range'];
    return SizedBox(height: 38, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: labels.length, separatorBuilder: (_, _) => const SizedBox(width: 8), itemBuilder: (_, index) => InkWell(onTap: () => index == 4 ? _pickCustomRange() : setState(() => selectedPreset = index), borderRadius: BorderRadius.circular(13), child: Container(width: index == 4 ? 112 : 96, alignment: Alignment.center, decoration: BoxDecoration(color: selectedPreset == index ? AppColors.primary : context.surfaceColor, borderRadius: BorderRadius.circular(13), border: Border.all(color: selectedPreset == index ? AppColors.primary : context.outlineColor)), child: Text(labels[index], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: selectedPreset == index ? Colors.white : context.secondaryTextColor))))));
  }

  Widget _summaryGrid(double income, double expenses, double closing, double average, int incomeCount, int expenseCount, String currency) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        _summaryCard(width, Icons.arrow_upward_rounded, AppColors.primary, 'Total Income', CurrencyUtils.format(income, currency: currency), '$incomeCount transactions'),
        _summaryCard(width, Icons.arrow_downward_rounded, AppColors.red, 'Total Expenses', CurrencyUtils.format(expenses, currency: currency), '$expenseCount transactions'),
        _summaryCard(width, Icons.account_balance_wallet_rounded, AppColors.blue, 'Closing Balance', CurrencyUtils.format(closing, currency: currency), 'Income - expenses'),
        _summaryCard(width, Icons.bar_chart_rounded, AppColors.purple, 'Average Daily Expense', CurrencyUtils.format(average, currency: currency), 'Elapsed calendar days'),
      ]);
    });
  }

  Widget _summaryCard(double width, IconData icon, Color color, String title, String value, String subtitle) {
    return Container(width: width, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.outlineColor)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 31, height: 31, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 17, color: color)), const SizedBox(height: 8), Text(title, maxLines: 2, style: TextStyle(fontSize: 9, color: context.secondaryTextColor)), const SizedBox(height: 2), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 8, color: context.secondaryTextColor))]));
  }

  Widget _chartsCard(List<Expense> expenses, List<Income> incomes, Map<String, double> categories, double totalExpenses, String currency) {
    final entries = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final categoryChart = SizedBox(
      height: 210,
      child: Row(
        children: [
          Expanded(
            child: entries.isEmpty
                ? Center(child: Text('No expenses in this period', style: TextStyle(fontSize: 10, color: context.secondaryTextColor)))
                : PieChart(PieChartData(
                    centerSpaceRadius: 42,
                    sectionsSpace: 2,
                    sections: entries.map((entry) => PieChartSectionData(value: entry.value, color: CategoryIcon.getColor(entry.key), radius: 32, showTitle: false)).toList(),
                  )),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: entries.take(5).map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: CategoryIcon.getColor(entry.key), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9))),
                      Text(CurrencyUtils.format(entry.value, currency: currency), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                    ]),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
    return Column(children: [_sectionCard('Income vs Expense', _barChart(expenses, incomes, currency)), const SizedBox(height: 10), _sectionCard('Spending by Category', categoryChart)]);
  }

  Widget _sectionCard(String title, Widget child) => Container(padding: const EdgeInsets.fromLTRB(12, 12, 12, 9), decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(17), border: Border.all(color: context.outlineColor)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 8), child]));

  Widget _barChart(List<Expense> expenses, List<Income> incomes, String currency) {
    final buckets = List<double>.filled(5, 0);
    final incomeBuckets = List<double>.filled(5, 0);
    final totalDays = range.end.difference(range.start).inDays + 1;
    int bucket(DateTime date) => ((date.difference(range.start).inDays * 5) ~/ totalDays).clamp(0, 4);
    for (final item in expenses) {
      buckets[bucket(item.date)] += item.amount;
    }
    for (final item in incomes) {
      incomeBuckets[bucket(item.date)] += item.amount;
    }
    final maxValue = [...buckets, ...incomeBuckets].fold<double>(0, (max, value) => value > max ? value : max);
    return SizedBox(height: 205, child: BarChart(BarChartData(maxY: maxValue == 0 ? 100 : maxValue * 1.25, barTouchData: BarTouchData(enabled: false), gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: context.outlineColor, strokeWidth: .6)), borderData: FlBorderData(show: false), titlesData: FlTitlesData(leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 18, getTitlesWidget: (value, meta) => Text('W${value.toInt() + 1}', style: TextStyle(fontSize: 8, color: context.secondaryTextColor))))), barGroups: List.generate(5, (index) => BarChartGroupData(x: index, barsSpace: 3, barRods: [BarChartRodData(toY: incomeBuckets[index], width: 13, color: AppColors.primary, borderRadius: BorderRadius.circular(4)), BarChartRodData(toY: buckets[index], width: 13, color: AppColors.red, borderRadius: BorderRadius.circular(4))])))));
  }

  Widget _transactionCard(List<Expense> expenses, List<Income> incomes, String currency) {
    final rows = <_StatementRow>[...incomes.map((item) => _StatementRow.income(item)), ...expenses.map((item) => _StatementRow.expense(item))]..sort((a, b) => b.date.compareTo(a.date));
    return _sectionCard('Transaction Details', Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Showing ${rows.length} of ${rows.length}', style: TextStyle(fontSize: 9, color: context.secondaryTextColor)), IconButton(onPressed: _exportStatement, icon: const Icon(Icons.download_rounded, size: 17), tooltip: 'Export statement')]), if (rows.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No transactions in this period', style: TextStyle(fontSize: 10, color: context.secondaryTextColor))) else ...rows.take(30).map((row) => _transactionRow(row, currency))]));
  }

  Widget _transactionRow(_StatementRow row, String currency) {
    final color = row.isIncome ? AppColors.primary : AppColors.red;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Container(width: 25, height: 25, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)), child: Icon(row.isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: color)), const SizedBox(width: 7), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), Text('${AppDateUtils.formatDate(row.date)} • ${row.category}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: context.secondaryTextColor))])), Text('${row.isIncome ? '+' : '-'} ${CurrencyUtils.format(row.amount, currency: currency)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))]));
  }

  Widget _closingCard(double opening, double income, double expenses, double closing, String currency) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: context.mutedSurfaceColor, borderRadius: BorderRadius.circular(16)), child: Row(children: [Expanded(child: _bottomStat('Opening', opening, currency)), _verticalDivider(), Expanded(child: _bottomStat('Income', income, currency)), _verticalDivider(), Expanded(child: _bottomStat('Expenses', expenses, currency)), _verticalDivider(), Expanded(child: _bottomStat('Closing', closing, currency))]));

  Widget _bottomStat(String label, double value, String currency) => Column(children: [Text(label, style: TextStyle(fontSize: 8, color: context.secondaryTextColor)), const SizedBox(height: 3), Text(CurrencyUtils.format(value, currency: currency), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))]);

  Widget _verticalDivider() => Container(width: 1, height: 28, color: context.outlineColor);

  Future<void> _pickCustomRange() async {
    final picked = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CustomRangeSheet(initialRange: customRange),
    );
    if (picked != null) setState(() { selectedPreset = 4; customRange = picked; });
  }

  Future<void> _showFilter(BuildContext context) async {
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [const Padding(padding: EdgeInsets.fromLTRB(20, 3, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Statement period', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))), ...['This Month', 'Last Month', 'Last 3 Months', 'This Year'].asMap().entries.map((entry) => ListTile(title: Text(entry.value), trailing: selectedPreset == entry.key ? const Icon(Icons.check_rounded, color: AppColors.primary) : null, onTap: () { setState(() => selectedPreset = entry.key); Navigator.pop(context); })), ListTile(title: const Text('Custom Range'), trailing: const Icon(Icons.date_range_rounded), onTap: () { Navigator.pop(context); _pickCustomRange(); }), const SizedBox(height: 8)])));
  }

  void _previousPreset() => setState(() => selectedPreset = selectedPreset == 0 ? 3 : selectedPreset - 1);
  void _nextPreset() => setState(() => selectedPreset = selectedPreset == 3 ? 0 : selectedPreset + 1);

  Future<void> _exportStatement() async {
    final provider = context.read<ExpenseProvider>();
    final expenses = provider.expenses.where((item) => _inRange(item.date)).toList();
    final incomes = provider.incomes.where((item) => _inRange(item.date)).toList();
    final bytes = await StatementPdfService.build(
      period: range,
      expenses: expenses,
      incomes: incomes,
      openingBalance: _openingBalance(provider),
      currency: context.read<SettingsProvider>().currency,
    );
    final path = await FilePicker.saveFile(dialogTitle: 'Export statement PDF', fileName: 'spend_smart_statement.pdf', type: FileType.custom, allowedExtensions: ['pdf'], bytes: bytes);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path == null ? 'Export cancelled' : 'Statement exported successfully')));
  }
}

class _StatementRow {
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final bool isIncome;

  const _StatementRow({required this.title, required this.category, required this.amount, required this.date, required this.isIncome});

  factory _StatementRow.income(Income item) => _StatementRow(title: item.title, category: item.source, amount: item.amount, date: item.date, isIncome: true);
  factory _StatementRow.expense(Expense item) => _StatementRow(title: item.title, category: item.category, amount: item.amount, date: item.date, isIncome: false);
}

class _CustomRangeSheet extends StatefulWidget {
  final DateTimeRange? initialRange;

  const _CustomRangeSheet({this.initialRange});

  @override
  State<_CustomRangeSheet> createState() => _CustomRangeSheetState();
}

class _CustomRangeSheetState extends State<_CustomRangeSheet> {
  late DateTime start;
  late DateTime end;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    start = widget.initialRange?.start ?? DateTime(now.year, now.month, 1);
    end = widget.initialRange?.end ?? now;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Custom statement range', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Choose the start and end date for your statement.', style: TextStyle(fontSize: 9, color: context.secondaryTextColor)),
            const SizedBox(height: 16),
            Row(children: [Expanded(child: _dateCard('Start date', start, _pickStart)), const SizedBox(width: 9), Expanded(child: _dateCard('End date', end, _pickEnd))]),
            const SizedBox(height: 16),
            Text('Quick select', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: context.secondaryTextColor)),
            const SizedBox(height: 7),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _quickChip('This month', _setThisMonth),
              _quickChip('Last month', _setLastMonth),
              _quickChip('Last 3 months', _setLastThreeMonths),
              _quickChip('Year to date', _setYearToDate),
            ]),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 44, child: FilledButton(onPressed: () => Navigator.pop(context, DateTimeRange(start: DateTime(start.year, start.month, start.day), end: DateTime(end.year, end.month, end.day, 23, 59, 59))), child: const Text('Apply range'))),
          ]),
        ),
      ),
    );
  }

  Widget _dateCard(String label, DateTime date, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(13), child: Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: context.fieldColor, borderRadius: BorderRadius.circular(13), border: Border.all(color: context.outlineColor)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 8, color: context.secondaryTextColor)), const SizedBox(height: 5), Row(children: [const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.primary), const SizedBox(width: 5), Expanded(child: Text(AppDateUtils.formatDate(date), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))), const Icon(Icons.chevron_right_rounded, size: 16)])])));
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: context.mutedSurfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.outlineColor)), child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))));
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final selected = await showDatePicker(context: context, initialDate: start.isAfter(now) ? now : start, firstDate: DateTime(now.year - 3), lastDate: now);
    if (selected != null && mounted) setState(() { start = selected; if (end.isBefore(start)) end = start; });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final selected = await showDatePicker(context: context, initialDate: end.isAfter(now) ? now : end, firstDate: start, lastDate: now);
    if (selected != null && mounted) setState(() => end = selected);
  }

  void _setThisMonth() {
    final now = DateTime.now();
    setState(() { start = DateTime(now.year, now.month, 1); end = now; });
  }

  void _setLastMonth() {
    final now = DateTime.now();
    setState(() { start = DateTime(now.year, now.month - 1, 1); end = DateTime(now.year, now.month, 0); });
  }

  void _setLastThreeMonths() {
    final now = DateTime.now();
    setState(() { start = DateTime(now.year, now.month - 2, 1); end = now; });
  }

  void _setYearToDate() {
    final now = DateTime.now();
    setState(() { start = DateTime(now.year, 1, 1); end = now; });
  }
}
