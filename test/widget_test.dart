// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:spend_smart/app.dart';
import 'package:spend_smart/screens/main/main_screen.dart';
import 'package:spend_smart/data/models/expense.dart';
import 'package:spend_smart/widgets/expense_tile.dart';
import 'package:spend_smart/providers/expense_provider.dart';
import 'package:spend_smart/providers/settings_provider.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1024, 1366),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('main screens fit $size at text scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final settings = SettingsProvider();
        await settings.loadSettings();
        await settings.completeOnboarding();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ExpenseProvider()),
              ChangeNotifierProvider(create: (_) => settings),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const MainScreen(),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(FloatingActionButton)),
          const Size(56, 56),
        );
        for (final label in ['History', 'Reports', 'Settings', 'Home']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('expense tile works inside a colored card', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Container(
            color: Colors.white,
            child: ExpenseTile(
              expense: Expense(
                title: 'Lunch',
                amount: 100,
                category: 'Food',
                date: DateTime(2026, 10, 8),
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lunch'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app builds with providers', (WidgetTester tester) async {
    final settings = SettingsProvider();
    await settings.loadSettings();
    await settings.completeOnboarding();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
          ChangeNotifierProvider(create: (_) => settings),
        ],
        child: const SpendSmartApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Backup & Restore'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first launch shows onboarding and Skip opens main', (
    tester,
  ) async {
    final settings = SettingsProvider();
    await settings.loadSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
          ChangeNotifierProvider(create: (_) => settings),
        ],
        child: const SpendSmartApp(),
      ),
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final reloaded = SettingsProvider();
    await reloaded.loadSettings();
    expect(reloaded.onboardingCompleted, isTrue);
  });
}
