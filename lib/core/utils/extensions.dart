import 'package:intl/intl.dart';

extension DoubleExt on double {
  String toCurrency() => 'GH₵${NumberFormat('#,##0.00').format(this)}';
}

extension DateTimeExt on DateTime {
  String toDisplay() => DateFormat('MMM d, yyyy • h:mm a').format(this);
  String toDateOnly() => DateFormat('MMM d, yyyy').format(this);
}

extension StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
