import 'package:flutter/material.dart';

import '../add_expense/add_expense_redesign.dart';
import '../history/history_redesign.dart';
import '../home/home_screen_redesign.dart';
import '../reports/reports_redesign.dart';
import '../settings/settings_redesign.dart';
import '../income/add_income_redesign.dart';
import '../../widgets/app_bottom_navigation.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      HomeScreen(
        onSeeAll: () => setState(() => currentIndex = 1),
        onOpenReports: () => setState(() => currentIndex = 2),
        onOpenSettings: () => setState(() => currentIndex = 3),
      ),
      const HistoryScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),

      floatingActionButton: FloatingActionButton(
        heroTag: 'main-add-expense',
        tooltip: 'Add income or expense',
        onPressed: () async {
          final income = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.remove_circle_outline),
                      title: const Text('Add expense'),
                      subtitle: const Text('Record money spent'),
                      onTap: () => Navigator.pop(context, false),
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Add income'),
                      subtitle: const Text('Record salary or money received'),
                      onTap: () => Navigator.pop(context, true),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
          if (income == null || !context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  income ? const AddIncomeScreen() : const AddExpenseScreen(),
            ),
          );
        },
        child: const Icon(Icons.add_rounded, size: 26),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: currentIndex,
        onItemSelected: (index) => setState(() => currentIndex = index),
      ),
    );
  }
}
