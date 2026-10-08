import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/expense_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding
      .ensureInitialized();

  await NotificationService.instance.initialize();

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
