import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// The three activities HealthMate tracks for every entry.
enum HealthMetric { steps, calories, water }

/// MODEL – one row of the `health_records` table.
///
/// Fields match the table required by the brief:
/// id (PK), date (text), steps (int), calories (int), water (int, ml).
///
/// The model is immutable: to change a record a new copy is created with
/// [copyWith]. This keeps state changes predictable in the controller.
@immutable
class HealthRecord {
  const HealthRecord({
    this.id,
    required this.date,
    required this.steps,
    required this.calories,
    required this.water,
  });

  /// Primary key. `null` until the record has been inserted.
  final int? id;

  /// Day the activity belongs to (time part is always midnight).
  final DateTime date;

  /// Steps walked.
  final int steps;

  /// Calories burned (kcal).
  final int calories;

  /// Water intake in millilitres.
  final int water;

  // Column names of the health_records table.
  static const String colId = 'id';
  static const String colDate = 'date';
  static const String colSteps = 'steps';
  static const String colCalories = 'calories';
  static const String colWater = 'water';

  /// Builds a record from a database row.
  factory HealthRecord.fromMap(Map<String, Object?> map) {
    return HealthRecord(
      id: map[colId] as int?,
      date: DateUtil.fromDbString(map[colDate] as String),
      steps: (map[colSteps] as int?) ?? 0,
      calories: (map[colCalories] as int?) ?? 0,
      water: (map[colWater] as int?) ?? 0,
    );
  }

  /// Converts the record into a database row.
  Map<String, Object?> toMap() {
    return {
      if (id != null) colId: id,
      colDate: DateUtil.toDbString(date),
      colSteps: steps,
      colCalories: calories,
      colWater: water,
    };
  }

  HealthRecord copyWith({
    int? id,
    DateTime? date,
    int? steps,
    int? calories,
    int? water,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      steps: steps ?? this.steps,
      calories: calories ?? this.calories,
      water: water ?? this.water,
    );
  }

  /// Value of one metric (used by charts and summaries).
  int valueOf(HealthMetric metric) {
    switch (metric) {
      case HealthMetric.steps:
        return steps;
      case HealthMetric.calories:
        return calories;
      case HealthMetric.water:
        return water;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthRecord &&
          other.id == id &&
          DateUtil.isSameDay(other.date, date) &&
          other.steps == steps &&
          other.calories == calories &&
          other.water == water;

  @override
  int get hashCode =>
      Object.hash(id, DateUtil.toDbString(date), steps, calories, water);

  @override
  String toString() =>
      'HealthRecord(id: $id, date: ${DateUtil.toDbString(date)}, '
      'steps: $steps, calories: $calories, water: $water)';
}

/// Totals for one calendar day (all entries of that day added together).
@immutable
class DailySummary {
  const DailySummary({
    required this.date,
    this.steps = 0,
    this.calories = 0,
    this.water = 0,
    this.entryCount = 0,
  });

  final DateTime date;
  final int steps;
  final int calories;
  final int water;
  final int entryCount;

  bool get hasData => entryCount > 0;

  int valueOf(HealthMetric metric) {
    switch (metric) {
      case HealthMetric.steps:
        return steps;
      case HealthMetric.calories:
        return calories;
      case HealthMetric.water:
        return water;
    }
  }

  DailySummary add(HealthRecord r) => DailySummary(
        date: date,
        steps: steps + r.steps,
        calories: calories + r.calories,
        water: water + r.water,
        entryCount: entryCount + 1,
      );
}

/// The user's daily targets, used for dashboard progress.
@immutable
class DailyGoals {
  const DailyGoals({
    this.steps = 10000,
    this.calories = 500,
    this.water = 2500,
  });

  final int steps;
  final int calories;
  final int water;

  static const DailyGoals defaults = DailyGoals();

  int valueOf(HealthMetric metric) {
    switch (metric) {
      case HealthMetric.steps:
        return steps;
      case HealthMetric.calories:
        return calories;
      case HealthMetric.water:
        return water;
    }
  }

  DailyGoals copyWithMetric(HealthMetric metric, int value) {
    switch (metric) {
      case HealthMetric.steps:
        return DailyGoals(steps: value, calories: calories, water: water);
      case HealthMetric.calories:
        return DailyGoals(steps: steps, calories: value, water: water);
      case HealthMetric.water:
        return DailyGoals(steps: steps, calories: calories, water: value);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DailyGoals &&
      other.steps == steps &&
      other.calories == calories &&
      other.water == water;

  @override
  int get hashCode => Object.hash(steps, calories, water);
}

/// Date helpers.
///
/// Dates are stored as TEXT in ISO format `yyyy-MM-dd`. This format sorts
/// correctly as a string, so ordering and range searches work directly.
class DateUtil {
  DateUtil._();

  static final DateFormat _dbFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _longFormat = DateFormat('d MMMM yyyy');
  static final DateFormat _mediumFormat = DateFormat('EEE, d MMM yyyy');
  static final DateFormat _shortDay = DateFormat('EEE');
  static final DateFormat _dayMonth = DateFormat('d MMM');

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// `DateTime` -> `"2026-08-18"`
  static String toDbString(DateTime value) => _dbFormat.format(value);

  /// `"2026-08-18"` -> `DateTime`
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

  /// Whole calendar days from [from] to [to] (UTC maths, so daylight
  /// saving changes do not break it).
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// "Today", "Yesterday" or "Tue, 18 Aug 2026".
  static String relativeLabel(DateTime value, {DateTime? now}) {
    final diff = daysBetween(value, now ?? DateTime.now());
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return mediumDate(value);
  }

  static String greeting({DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Number formatting helpers.
class NumberUtil {
  NumberUtil._();

  static final NumberFormat _decimal = NumberFormat.decimalPattern('en_US');
  static final NumberFormat _compact = NumberFormat.compact(locale: 'en_US');

  /// 7850 -> "7,850"
  static String formatInt(int value) => _decimal.format(value);

  /// 7850 -> "7.9K"
  static String compact(int value) => _compact.format(value);
}
