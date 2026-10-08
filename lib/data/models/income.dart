class Income {
  final int? id;
  final String title;
  final double amount;
  final String source;
  final DateTime date;
  final String? note;

  const Income({
    this.id,
    required this.title,
    required this.amount,
    required this.source,
    required this.date,
    this.note,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'source': source,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory Income.fromMap(Map<String, Object?> map) => Income(
    id: map['id'] as int?,
    title: map['title'] as String,
    amount: (map['amount'] as num).toDouble(),
    source: map['source'] as String,
    date: DateTime.parse(map['date'] as String),
    note: map['note'] as String?,
  );
}
