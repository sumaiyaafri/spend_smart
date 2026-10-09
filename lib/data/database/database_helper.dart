import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(databasePath, 'spend_smart.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createIncomeTable(db);
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE expenses ADD COLUMN is_recurring INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 4) await _createRecurringTables(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_expense_date ON expenses(date)');

    await db.execute('CREATE INDEX idx_expense_category ON expenses(category)');
    await _createIncomeTable(db);
    await _createRecurringTables(db);
  }

  Future<void> _createRecurringTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS recurring_expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      category TEXT NOT NULL,
      due_day INTEGER NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS recurring_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recurring_id INTEGER NOT NULL,
      month_key TEXT NOT NULL,
      paid_at TEXT NOT NULL,
      expense_id INTEGER,
      UNIQUE(recurring_id, month_key)
    )''');
  }

  Future<void> _createIncomeTable(Database db) async {
    await db.execute('''CREATE TABLE incomes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      source TEXT NOT NULL,
      date TEXT NOT NULL,
      note TEXT
    )''');
    await db.execute('CREATE INDEX idx_income_date ON incomes(date)');
  }

  Future<List<Income>> getIncomes() async {
    final db = await database;
    final rows = await db.query('incomes', orderBy: 'date DESC, id DESC');
    return rows.map(Income.fromMap).toList();
  }

  Future<void> saveIncome(Income income) async {
    final db = await database;
    if (income.id == null) {
      await db.insert('incomes', income.toMap());
    } else {
      await db.update(
        'incomes',
        income.toMap(),
        where: 'id = ?',
        whereArgs: [income.id],
      );
    }
  }

  Future<void> deleteIncome(int id) async {
    final db = await database;
    await db.delete('incomes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final db = await database;
    final rows = await db.query('recurring_expenses', orderBy: 'due_day ASC, id DESC');
    return rows.map(RecurringExpense.fromMap).toList();
  }

  Future<void> saveRecurringExpense(RecurringExpense recurring) async {
    final db = await database;
    if (recurring.id == null) {
      await db.insert('recurring_expenses', recurring.toMap()..remove('id'));
    } else {
      await db.update('recurring_expenses', recurring.toMap()..remove('id'), where: 'id = ?', whereArgs: [recurring.id]);
    }
  }

  Future<void> deleteRecurringExpense(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('recurring_payments', where: 'recurring_id = ?', whereArgs: [id]);
      await txn.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<Set<String>> getRecurringPaymentKeys(String monthKey) async {
    final db = await database;
    final rows = await db.query('recurring_payments', columns: ['recurring_id'], where: 'month_key = ?', whereArgs: [monthKey]);
    return rows.map((row) => '${row['recurring_id']}').toSet();
  }

  Future<void> recordRecurringPayment({required RecurringExpense recurring, required DateTime paidAt}) async {
    final recurringId = recurring.id;
    if (recurringId == null) return;
    final monthKey = '${paidAt.year}-${paidAt.month.toString().padLeft(2, '0')}';
    final db = await database;
    await db.transaction((txn) async {
      final alreadyPaid = await txn.query('recurring_payments', where: 'recurring_id = ? AND month_key = ?', whereArgs: [recurringId, monthKey], limit: 1);
      if (alreadyPaid.isNotEmpty) return;
      final expenseId = await txn.insert('expenses', {
        'title': recurring.title,
        'amount': recurring.amount,
        'category': recurring.category,
        'date': paidAt.toIso8601String(),
        'note': 'Recurring payment',
        'is_recurring': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.insert('recurring_payments', {
        'recurring_id': recurringId,
        'month_key': monthKey,
        'paid_at': paidAt.toIso8601String(),
        'expense_id': expenseId,
      });
    });
  }

  Future<void> restoreBackup({required List<Expense> expenses, required List<Income> incomes}) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final expense in expenses) {
        final values = expense.toMap()..remove('id');
        await txn.insert('expenses', values);
      }
      for (final income in incomes) {
        final values = income.toMap()..remove('id');
        await txn.insert('incomes', values);
      }
    });
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;

    return db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;

    final result = await db.query('expenses', orderBy: 'date DESC');

    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;

    return db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;

    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
