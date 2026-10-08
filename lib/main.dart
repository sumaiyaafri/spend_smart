import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/expense_provider.dart';
import 'providers/settings_provider.dart';

void main() {
  WidgetsFlutterBinding
      .ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              ExpenseProvider()
                ..loadExpenses(),
        ),

        ChangeNotifierProvider(
          create: (_) =>
              SettingsProvider()
                ..loadSettings(),
        ),
      ],
      child:
          const SpendSmartApp(),
    ),
  );
}