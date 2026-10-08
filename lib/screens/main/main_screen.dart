import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../add_expense/add_expense_screen.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    HomeScreen(),
    HistoryScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: IndexedStack(index: currentIndex, children: pages),

      floatingActionButton: FloatingActionButton(
        heroTag: 'main-add-expense',
        tooltip: 'Add expense',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
        },
        child: const Icon(Icons.add_rounded, size: 26),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 10,
        height: 60 + MediaQuery.textScalerOf(context).scale(14),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _navigationItem(index: 0, icon: Icons.home_rounded, label: 'Home'),

            _navigationItem(
              index: 1,
              icon: Icons.history_rounded,
              label: 'History',
            ),

            const SizedBox(width: 72),

            _navigationItem(
              index: 2,
              icon: Icons.bar_chart_rounded,
              label: 'Reports',
            ),

            _navigationItem(
              index: 3,
              icon: Icons.settings_rounded,
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigationItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = currentIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            currentIndex = index;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? AppColors.primary : Colors.grey),

              const SizedBox(height: 3),

              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.primary : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
