import 'package:flutter/foundation.dart';

import '../../../../core/constants/health_metric.dart';
import '../../../../core/utils/date_helpers.dart';

/// One row of the `health_records` table.
///
/// The model is immutable: to change a record the app creates a new copy
/// with [copyWith]. This keeps state changes predictable in the view model.
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

  // Column names — shared with the database helper and repository.
  static const String colId = 'id';
  static const String colDate = 'date';
  static const String colSteps = 'steps';
  static const String colCalories = 'calories';
  static const String colWater = 'water';

  /// Builds a record from a database row.
  factory HealthRecord.fromMap(Map<String, Object?> map) {
    return HealthRecord(
      id: map[colId] as int?,
      date: DateHelpers.fromDbString(map[colDate] as String),
      steps: (map[colSteps] as int?) ?? 0,
      calories: (map[colCalories] as int?) ?? 0,
      water: (map[colWater] as int?) ?? 0,
    );
  }

  /// Converts the record into a map (ready for database storage).
  Map<String, Object?> toMap() {
    return {
      if (id != null) colId: id,
      colDate: DateHelpers.toDbString(date),
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

  /// Returns the value of a given metric (used by charts and summaries).
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
          DateHelpers.isSameDay(other.date, date) &&
          other.steps == steps &&
          other.calories == calories &&
          other.water == water;

  @override
  int get hashCode => Object.hash(
        id,
        DateHelpers.toDbString(date),
        steps,
        calories,
        water,
      );

  @override
  String toString() =>
      'HealthRecord(id: $id, date: ${DateHelpers.toDbString(date)}, '
      'steps: $steps, calories: $calories, water: $water)';
}
