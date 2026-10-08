import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/expense_tile.dart';
import '../expense_details/expense_details_screen.dart';

enum HistoryFilter {
  today,
  week,
  month,
  all,
}

class HistoryScreen
    extends StatefulWidget {
  const HistoryScreen({
    super.key,
  });

  @override
  State<HistoryScreen> createState() =>
      _HistoryScreenState();
}

class _HistoryScreenState
    extends State<HistoryScreen> {
  HistoryFilter selectedFilter =
      HistoryFilter.all;

  String search = '';

  List<Expense> _filterExpenses(
    List<Expense> expenses,
  ) {
    return expenses.where((expense) {
      bool matchesFilter = true;

      switch (selectedFilter) {
        case HistoryFilter.today:
          matchesFilter =
              AppDateUtils.isSameDay(
            expense.date,
            DateTime.now(),
          );
          break;

        case HistoryFilter.week:
          matchesFilter =
              AppDateUtils.isThisWeek(
            expense.date,
          );
          break;

        case HistoryFilter.month:
          matchesFilter =
              AppDateUtils.isThisMonth(
            expense.date,
          );
          break;

        case HistoryFilter.all:
          matchesFilter = true;
      }

      final query =
          search.trim().toLowerCase();

      final matchesSearch =
          query.isEmpty ||
              expense.title
                  .toLowerCase()
                  .contains(query) ||
              expense.category
                  .toLowerCase()
                  .contains(query);

      return matchesFilter &&
          matchesSearch;
    }).toList();
  }

  Map<DateTime, List<Expense>>
      _groupExpenses(
    List<Expense> expenses,
  ) {
    final Map<DateTime, List<Expense>>
        groups = {};

    for (final expense in expenses) {
      final day = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );

      groups
          .putIfAbsent(
            day,
            () => [],
          )
          .add(expense);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<ExpenseProvider>();

    final filtered =
        _filterExpenses(
      provider.expenses,
    );

    final grouped =
        _groupExpenses(filtered);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              10,
            ),
            child: Column(
              children: [
                const Text(
                  'Expense History',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  onChanged: (value) {
                    setState(() {
                      search = value;
                    });
                  },
                  decoration:
                      const InputDecoration(
                    hintText:
                        'Search expenses...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(
                        'Today',
                        HistoryFilter.today,
                      ),
                      _filterChip(
                        'This Week',
                        HistoryFilter.week,
                      ),
                      _filterChip(
                        'This Month',
                        HistoryFilter.month,
                      ),
                      _filterChip(
                        'All',
                        HistoryFilter.all,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    title:
                        'No expenses found',
                    message:
                        'Try changing your search or filter.',
                    icon: Icons
                        .search_off_rounded,
                  )
                : ListView(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      20,
                      10,
                      20,
                      110,
                    ),
                    children:
                        grouped.entries
                            .map(
                              (entry) =>
                                  _buildGroup(
                                entry.key,
                                entry.value,
                              ),
                            )
                            .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    HistoryFilter filter,
  ) {
    final selected =
        selectedFilter == filter;

    return Padding(
      padding:
          const EdgeInsets.only(
        right: 8,
      ),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            selectedFilter = filter;
          });
        },
      ),
    );
  }

  Widget _buildGroup(
    DateTime day,
    List<Expense> expenses,
  ) {
    final total =
        expenses.fold<double>(
      0,
      (sum, item) =>
          sum + item.amount,
    );

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 22,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              Text(
                AppDateUtils.isSameDay(
                  day,
                  DateTime.now(),
                )
                    ? 'Today'
                    : AppDateUtils
                        .formatDate(day),
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              Text(
                '৳ ${total.toStringAsFixed(0)}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 15,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color:
                  Theme.of(context)
                      .cardColor,
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),
            child: Column(
              children: expenses
                  .map(
                    (expense) =>
                        ExpenseTile(
                      expense:
                          expense,
                      onTap:
                          () async {
                        await Navigator
                            .push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ExpenseDetailsScreen(
                              expense:
                                  expense,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}