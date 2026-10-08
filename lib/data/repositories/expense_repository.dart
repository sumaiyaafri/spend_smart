import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/income.dart';

class ExpenseRepository {
  final DatabaseHelper databaseHelper;

  ExpenseRepository({DatabaseHelper? databaseHelper})
    : databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<List<Expense>> getExpenses() {
    return databaseHelper.getExpenses();
  }

  Future<List<Income>> getIncomes() => databaseHelper.getIncomes();
  Future<void> saveIncome(Income income) => databaseHelper.saveIncome(income);
  Future<void> deleteIncome(int id) => databaseHelper.deleteIncome(id);

  Future<void> restoreBackup({required List<Expense> expenses, required List<Income> incomes}) => databaseHelper.restoreBackup(expenses: expenses, incomes: incomes);

  Future<void> addExpense(Expense expense) async {
    await databaseHelper.insertExpense(expense);
  }

  Future<void> updateExpense(Expense expense) async {
    await databaseHelper.updateExpense(expense);
  }

  Future<void> deleteExpense(int id) async {
    await databaseHelper.deleteExpense(id);
  }
}
