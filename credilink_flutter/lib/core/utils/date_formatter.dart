import 'package:intl/intl.dart';

class DateFormatter {
  static String format(DateTime date) => DateFormat.yMMMd().format(date);

  static String formatDateTime(DateTime date) => DateFormat.yMMMd().add_jm().format(date);
}
