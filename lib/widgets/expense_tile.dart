import 'package:flutter/material.dart';

import '../data/models/expense.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;

  const ExpenseTile({super.key, required this.expense, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: onTap,

        leading: CircleAvatar(child: const Icon(Icons.restaurant)),

        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),

        subtitle: Text(expense.category),

        trailing: Text(
          '৳ ${expense.amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
