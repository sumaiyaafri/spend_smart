class RecurringExpense {
  final int? id;
  final String title;
  final double amount;
  final String category;
  final int dueDay;
  final bool active;
  final DateTime createdAt;

  RecurringExpense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.dueDay,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'due_day': dueDay,
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory RecurringExpense.fromMap(Map<String, Object?> map) => RecurringExpense(
        id: map['id'] as int?,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        dueDay: map['due_day'] as int,
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  RecurringExpense copyWith({String? title, double? amount, String? category, int? dueDay, bool? active}) {
    return RecurringExpense(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dueDay: dueDay ?? this.dueDay,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }
}
