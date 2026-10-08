import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const AppBottomNavigationBar({super.key, required this.currentIndex, required this.onItemSelected});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 10,
      height: 60 + MediaQuery.textScalerOf(context).scale(14),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _navigationItem(context, index: 0, icon: Icons.home_rounded, label: 'Home'),
          _navigationItem(context, index: 1, icon: Icons.history_rounded, label: 'History'),
          const SizedBox(width: 72),
          _navigationItem(context, index: 2, icon: Icons.bar_chart_rounded, label: 'Reports'),
          _navigationItem(context, index: 3, icon: Icons.settings_rounded, label: 'Settings'),
        ],
      ),
    );
  }

  Widget _navigationItem(BuildContext context, {required int index, required IconData icon, required String label}) {
    final selected = currentIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onItemSelected(index),
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
                  child: Text(label, maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.primary : Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
