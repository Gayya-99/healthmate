import 'package:intl/intl.dart';

/// Number formatting used across the UI.
class NumberHelpers {
  NumberHelpers._();

  static final NumberFormat _decimal = NumberFormat.decimalPattern('en_US');
  static final NumberFormat _compact = NumberFormat.compact(locale: 'en_US');

  /// 7850 -> "7,850"
  static String formatInt(int value) => _decimal.format(value);

  /// 7850 -> "7.9K" (used on small chart labels)
  static String compact(int value) => _compact.format(value);
}
