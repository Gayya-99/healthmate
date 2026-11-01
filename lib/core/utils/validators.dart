import 'number_helpers.dart';

/// Form validation rules.
///
/// Validators are pure functions with no Flutter dependency, which makes
/// them easy to unit test (see `test/unit/validators_test.dart`).
class Validators {
  Validators._();

  /// Validates one health metric field (steps, calories or water).
  ///
  /// An empty field is allowed and treated as 0 so the user can log, for
  /// example, only water. Anything typed must be a whole number between
  /// 0 and [max].
  static String? Function(String?) metric({
    required String label,
    required int max,
  }) {
    return (String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return null;
      final number = int.tryParse(text);
      if (number == null) return 'Enter a whole number';
      if (number < 0) return '$label cannot be negative';
      if (number > max) {
        return '$label must be ${NumberHelpers.formatInt(max)} or less';
      }
      return null;
    };
  }

  /// Validates a daily goal value (must be 1..[max]).
  static String? Function(String?) goal({
    required String label,
    required int max,
  }) {
    return (String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return '$label goal is required';
      final number = int.tryParse(text);
      if (number == null) return 'Enter a whole number';
      if (number <= 0) return 'Goal must be greater than 0';
      if (number > max) {
        return 'Goal must be ${NumberHelpers.formatInt(max)} or less';
      }
      return null;
    };
  }

  /// Form-level rule: an entry must record at least one activity.
  static String? atLeastOneValue({
    required int steps,
    required int calories,
    required int water,
  }) {
    if (steps <= 0 && calories <= 0 && water <= 0) {
      return 'Enter at least one value greater than 0';
    }
    return null;
  }

  /// Entries cannot be recorded for a future date.
  static String? notInFuture(DateTime? date, {DateTime? now}) {
    if (date == null) return 'Please choose a date';
    final today = now ?? DateTime.now();
    final endOfToday =
        DateTime(today.year, today.month, today.day, 23, 59, 59);
    if (date.isAfter(endOfToday)) return 'Date cannot be in the future';
    return null;
  }

  /// Parses a text field into an int, treating empty as 0.
  static int parseOrZero(String? value) =>
      int.tryParse(value?.trim() ?? '') ?? 0;
}
