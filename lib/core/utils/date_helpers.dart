import 'package:intl/intl.dart';

/// Helpers for converting dates between the UI and the database.
///
/// Dates are stored in SQLite as TEXT in ISO format `yyyy-MM-dd`.
/// This format sorts correctly as a string, so `ORDER BY date` and
/// `WHERE date BETWEEN ? AND ?` work without any conversion in SQL.
class DateHelpers {
  DateHelpers._();

  static final DateFormat _dbFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _longFormat = DateFormat('d MMMM yyyy');
  static final DateFormat _mediumFormat = DateFormat('EEE, d MMM yyyy');
  static final DateFormat _shortDay = DateFormat('EEE');
  static final DateFormat _dayMonth = DateFormat('d MMM');

  /// Removes the time part so two values on the same day compare equal.
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// `DateTime` -> `"2026-08-18"` (database format).
  static String toDbString(DateTime value) => _dbFormat.format(value);

  /// `"2026-08-18"` -> `DateTime` (local midnight).
  static DateTime fromDbString(String value) => dateOnly(DateTime.parse(value));

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "18 August 2026"
  static String longDate(DateTime value) => _longFormat.format(value);

  /// "Tue, 18 Aug 2026"
  static String mediumDate(DateTime value) => _mediumFormat.format(value);

  /// "Tue"
  static String shortDay(DateTime value) => _shortDay.format(value);

  /// "18 Aug"
  static String dayMonth(DateTime value) => _dayMonth.format(value);

  /// "Today", "Yesterday" or "Tue, 18 Aug 2026".
  static String relativeLabel(DateTime value, {DateTime? now}) {
    final difference = daysBetween(value, now ?? DateTime.now());
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return mediumDate(value);
  }

  /// Whole calendar days from [from] to [to] (safe across daylight saving
  /// changes because the calculation is done in UTC).
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Greeting based on the time of day.
  static String greeting({DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
