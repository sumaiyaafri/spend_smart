import 'package:intl/intl.dart';

class CurrencyUtils {
  static String getSymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';

      case 'EUR':
        return '€';

      case 'BDT':
      default:
        return '৳';
    }
  }

  static String format(
    double amount, {
    String currency = 'BDT',
  }) {
    final formatter = NumberFormat('#,##0.##');

    return '${getSymbol(currency)} ${formatter.format(amount)}';
  }
}