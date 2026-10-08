import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:spend_smart/data/models/expense.dart';
import 'package:spend_smart/data/models/income.dart';
import 'package:spend_smart/data/repositories/expense_repository.dart';
import 'package:spend_smart/providers/expense_provider.dart';
import 'package:spend_smart/providers/settings_provider.dart';
import 'package:spend_smart/screens/income/income_screen.dart';

class MemoryRepository extends ExpenseRepository {
  final List<Income> records = [];
  final List<Expense> spending = [];
  int nextId = 1;
  @override
  Future<List<Expense>> getExpenses() async => List.of(spending);
  @override
  Future<List<Income>> getIncomes() async =>
      List.of(records)..sort((a, b) => b.date.compareTo(a.date));
  @override
  Future<void> saveIncome(Income income) async {
    final map = income.toMap();
    map['id'] = income.id ?? nextId++;
    records.removeWhere((item) => item.id == map['id']);
    records.add(Income.fromMap(map));
  }

  @override
  Future<void> deleteIncome(int id) async =>
      records.removeWhere((item) => item.id == id);
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'income dates, monthly totals, balance, edits and deletes survive reload',
    () async {
      final now = DateTime.now();
      final repository = MemoryRepository();
      repository.spending.add(
        Expense(
          title: 'Lunch',
          amount: 200,
          category: 'Food & Dining',
          date: now,
        ),
      );
      final provider = ExpenseProvider(repository: repository);
      await provider.loadExpenses();
      await provider.saveIncome(
        Income(
          title: 'Monthly salary',
          amount: 30000,
          source: 'Salary',
          date: now,
        ),
      );
      await provider.saveIncome(
        Income(title: 'Gift', amount: 1000, source: 'Gift', date: now),
      );
      await provider.saveIncome(
        Income(
          title: 'Old bonus',
          amount: 500,
          source: 'Bonus',
          date: DateTime(now.year, now.month - 1, 10),
        ),
      );
      expect(provider.monthIncome, 31000);
      expect(provider.balance, 31300);
      final salary = provider.incomes.firstWhere(
        (item) => item.title == 'Monthly salary',
      );
      await provider.saveIncome(
        Income(
          id: salary.id,
          title: salary.title,
          amount: 32000,
          source: salary.source,
          date: salary.date,
        ),
      );
      expect(provider.monthIncome, 33000);
      final restored = ExpenseProvider(repository: repository);
      await restored.loadExpenses();
      expect(restored.incomes.length, 3);
      expect(
        restored.incomes.firstWhere((item) => item.id == salary.id).date,
        now,
      );
      await restored.deleteIncome(salary.id!);
      expect(restored.monthIncome, 1000);
      expect(restored.balance, 1300);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1024, 1366),
  ]) {
    testWidgets('income list and form fit $size with large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final provider = ExpenseProvider(repository: MemoryRepository());
      await provider.saveIncome(
        Income(
          title: 'Monthly salary with a long descriptive title',
          amount: 30000,
          source: 'Salary',
          date: DateTime.now(),
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => provider),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: const IncomeScreen(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Add income'));
      await tester.pumpAndSettle();
      expect(find.text('Income title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('income form validates and saves a received payment', (
    tester,
  ) async {
    final provider = ExpenseProvider(repository: MemoryRepository());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => provider),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const MaterialApp(home: IncomeScreen()),
      ),
    );
    await tester.tap(find.text('Add income'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'October salary');
    await tester.enterText(find.byType(TextFormField).at(1), '-100');
    await tester.scrollUntilVisible(
      find.text('Save income'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Save income'));
    await tester.pumpAndSettle();
    expect(provider.incomes, isEmpty);
    await tester.enterText(find.byType(TextFormField).at(1), '25000');
    await tester.ensureVisible(find.text('Save income'));
    await tester.tap(find.text('Save income'));
    await tester.pumpAndSettle();
    expect(provider.incomes.single.amount, 25000);
    expect(provider.incomes.single.source, 'Salary');
    expect(find.text('October salary'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
