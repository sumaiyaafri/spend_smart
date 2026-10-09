import 'package:flutter/material.dart';

import '../data/models/expense.dart';
import '../data/models/income.dart';
import '../data/models/recurring_expense.dart';
import '../data/repositories/expense_repository.dart';
import '../services/notification_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseRepository repository;

  ExpenseProvider({ExpenseRepository? repository})
    : repository = repository ?? ExpenseRepository();

  List<Expense> _expenses = [];
  List<Income> _incomes = [];
  List<RecurringExpense> _recurringExpenses = [];
  Set<String> _recurringPaymentKeys = {};
  List<Income> get incomes => List.unmodifiable(_incomes);
  List<RecurringExpense> get recurringExpenses => List.unmodifiable(_recurringExpenses);
  double get totalIncome => _incomes.fold(0, (sum, item) => sum + item.amount);
  double get totalExpenses =>
      _expenses.fold(0, (sum, item) => sum + item.amount);
  double get balance => totalIncome - totalExpenses;
  double get monthIncome {
    final now = DateTime.now();
    return _incomes
        .where(
          (item) => item.date.year == now.year && item.date.month == now.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  bool _isLoading = false;

  String? _error;

  List<Expense> get expenses => List.unmodifiable(_expenses);

  bool get isLoading => _isLoading;

  String? get error => _error;

  Future<void> loadExpenses() async {
    _isLoading = true;
    _error = null;

    notifyListeners();

    try {
      _expenses = await repository.getExpenses();
      _incomes = await repository.getIncomes();
      _recurringExpenses = await repository.getRecurringExpenses();
      final now = DateTime.now();
      _recurringPaymentKeys = await repository.getRecurringPaymentKeys('${now.year}-${now.month.toString().padLeft(2, '0')}');
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(Expense expense) async {
    await repository.addExpense(expense);

    await loadExpenses();
    await NotificationService.instance.evaluateBudgetAlerts(
      todaySpent: todayTotal,
      monthSpent: monthTotal,
    );
  }

  Future<void> saveIncome(Income income) async {
    await repository.saveIncome(income);
    _incomes = await repository.getIncomes();
    notifyListeners();
  }

  Future<void> deleteIncome(int id) async {
    await repository.deleteIncome(id);
    _incomes = await repository.getIncomes();
    notifyListeners();
  }

  Future<void> saveRecurringExpense(RecurringExpense recurring) async {
    await repository.saveRecurringExpense(recurring);
    await loadExpenses();
    RecurringExpense? saved;
    for (final item in _recurringExpenses) {
      final matches = recurring.id != null
          ? item.id == recurring.id
          : item.title == recurring.title && item.amount == recurring.amount && item.dueDay == recurring.dueDay;
      if (matches) {
        saved = item;
        break;
      }
    }
    if (saved != null) await NotificationService.instance.scheduleRecurringExpense(saved);
  }

  Future<void> deleteRecurringExpense(RecurringExpense recurring) async {
    final id = recurring.id;
    if (id == null) return;
    await repository.deleteRecurringExpense(id);
    await loadExpenses();
    await NotificationService.instance.cancelRecurringExpense(id);
  }

  bool isRecurringPaid(RecurringExpense recurring) {
    return _recurringPaymentKeys.contains('${recurring.id}');
  }

  List<RecurringExpense> recurringDueToday(DateTime date) {
    return _recurringExpenses.where((item) => item.active && item.dueDay == date.day && !isRecurringPaid(item)).toList();
  }

  Future<void> markRecurringPaid(RecurringExpense recurring, DateTime paidAt) async {
    await repository.recordRecurringPayment(recurring: recurring, paidAt: paidAt);
    await loadExpenses();
  }

  Future<void> restoreBackup({required List<Expense> expenses, required List<Income> incomes}) async {
    await repository.restoreBackup(expenses: expenses, incomes: incomes);
    await loadExpenses();
  }

  Future<void> updateExpense(Expense expense) async {
    await repository.updateExpense(expense);

    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    await repository.deleteExpense(id);

    await loadExpenses();
  }

  List<Expense> get todayExpenses {
    final now = DateTime.now();

    return _expenses.where((expense) {
      return expense.date.year == now.year &&
          expense.date.month == now.month &&
          expense.date.day == now.day &&
          !expense.isRecurring;
    }).toList();
  }

  double get todayTotal {
    return todayExpenses.fold<double>(
      0,
      (total, expense) => total + expense.amount,
    );
  }

  List<Expense> get currentMonthExpenses {
    final now = DateTime.now();

    return _expenses.where((expense) {
      return expense.date.year == now.year && expense.date.month == now.month;

    }).toList();
  }

  double get monthTotal {
    return currentMonthExpenses.fold<double>(
      0,
      (total, expense) => total + expense.amount,
    );
  }

  Map<String, double> get categoryTotals {
    final Map<String, double> totals = {};

    for (final expense in currentMonthExpenses) {
      totals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    return totals;
  }
}
