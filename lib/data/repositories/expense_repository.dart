import '../database/database_helper.dart';
import '../models/expense.dart';

class ExpenseRepository {
  final DatabaseHelper databaseHelper;

  ExpenseRepository({
    DatabaseHelper? databaseHelper,
  }) : databaseHelper =
            databaseHelper ?? DatabaseHelper.instance;

  Future<List<Expense>> getExpenses() {
    return databaseHelper.getExpenses();
  }

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