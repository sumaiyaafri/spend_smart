import 'package:flutter/material.dart';

import '../../data/models/expense.dart';
import '../../screens/add_expense/add_expense_screen.dart';
import '../../screens/expense_details/expense_details_screen.dart';
import '../../screens/main/main_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic>
      generateRoute(
    RouteSettings settings,
  ) {
    switch (settings.name) {
      case AppRoutes.main:
        return MaterialPageRoute(
          builder: (_) =>
              const MainScreen(),
        );

      case AppRoutes.addExpense:
        final expense =
            settings.arguments
                as Expense?;

        return MaterialPageRoute(
          builder: (_) =>
              AddExpenseScreen(
            expense: expense,
          ),
        );

      case AppRoutes.expenseDetails:
        final expense =
            settings.arguments
                as Expense;

        return MaterialPageRoute(
          builder: (_) =>
              ExpenseDetailsScreen(
            expense: expense,
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const MainScreen(),
        );
    }
  }
}