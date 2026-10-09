import 'package:intl/intl.dart';

class AppDateUtils {
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  static String formatDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  static String formatDateWithDay(DateTime date) {
    return DateFormat('EEE, d MMM yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('d MMM yyyy, h:mm a').format(date);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  static DateTime startOfWeek(DateTime date) {
    final normalized = DateTime(
      date.year,
      date.month,
      date.day,
    );

    return normalized.subtract(
      Duration(days: normalized.weekday - 1),
    );
  }

  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();

    final start = startOfWeek(now);
    final end = start.add(const Duration(days: 7));

    return !date.isBefore(start) && date.isBefore(end);
  }

  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month;
  }

  /// Returns the number of calendar days that have elapsed in a range.
  ///
  /// For the current month/range, the denominator stops at today instead of
  /// counting future days. For a completed range, every day in that range is
  /// included. Both endpoints are inclusive.
  static int elapsedDaysInRange(
    DateTime start,
    DateTime end, {
    DateTime? today,
  }) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final todayDay = today == null
        ? DateTime.now()
        : DateTime(today.year, today.month, today.day);
    final effectiveEnd = endDay.isAfter(todayDay) ? todayDay : endDay;

    if (effectiveEnd.isBefore(startDay)) {
      return 0;
    }

    return effectiveEnd.difference(startDay).inDays + 1;
  }
}
