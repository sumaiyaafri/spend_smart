import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';
import '../models/income.dart';

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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createIncomeTable(db);
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
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_expense_date ON expenses(date)');

    await db.execute('CREATE INDEX idx_expense_category ON expenses(category)');
    await _createIncomeTable(db);
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
