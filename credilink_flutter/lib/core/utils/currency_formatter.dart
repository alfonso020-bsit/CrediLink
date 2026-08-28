import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _format = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

  static String format(num amount) => _format.format(amount);
}
