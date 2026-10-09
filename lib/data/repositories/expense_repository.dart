import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';

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

  Future<List<RecurringExpense>> getRecurringExpenses() => databaseHelper.getRecurringExpenses();
  Future<void> saveRecurringExpense(RecurringExpense recurring) => databaseHelper.saveRecurringExpense(recurring);
  Future<void> deleteRecurringExpense(int id) => databaseHelper.deleteRecurringExpense(id);
  Future<Set<String>> getRecurringPaymentKeys(String monthKey) => databaseHelper.getRecurringPaymentKeys(monthKey);
  Future<void> recordRecurringPayment({required RecurringExpense recurring, required DateTime paidAt}) => databaseHelper.recordRecurringPayment(recurring: recurring, paidAt: paidAt);

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
