import 'package:flutter/material.dart';

import '../data/models/expense.dart';
import '../data/repositories/expense_repository.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseRepository repository;

  ExpenseProvider({
    ExpenseRepository? repository,
  }) : repository =
            repository ?? ExpenseRepository();

  List<Expense> _expenses = [];

  bool _isLoading = false;

  String? _error;

  List<Expense> get expenses =>
      List.unmodifiable(_expenses);

  bool get isLoading => _isLoading;

  String? get error => _error;

  Future<void> loadExpenses() async {
    _isLoading = true;
    _error = null;

    notifyListeners();

    try {
      _expenses = await repository.getExpenses();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(
    Expense expense,
  ) async {
    await repository.addExpense(expense);

    await loadExpenses();
  }

  Future<void> updateExpense(
    Expense expense,
  ) async {
    await repository.updateExpense(expense);

    await loadExpenses();
  }

  Future<void> deleteExpense(
    int id,
  ) async {
    await repository.deleteExpense(id);

    await loadExpenses();
  }

  List<Expense> get todayExpenses {
    final now = DateTime.now();

    return _expenses.where((expense) {
      return expense.date.year == now.year &&
          expense.date.month == now.month &&
          expense.date.day == now.day;
    }).toList();
  }

  double get todayTotal {
    return todayExpenses.fold<double>(
      0,
      (total, expense) =>
          total + expense.amount,
    );
  }

  List<Expense> get currentMonthExpenses {
    final now = DateTime.now();

    return _expenses.where((expense) {
      return expense.date.year == now.year &&
          expense.date.month == now.month;
    }).toList();
  }

  double get monthTotal {
    return currentMonthExpenses.fold<double>(
      0,
      (total, expense) =>
          total + expense.amount,
    );
  }

  Map<String, double> get categoryTotals {
    final Map<String, double> totals = {};

    for (final expense
        in currentMonthExpenses) {
      totals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    return totals;
  }
}