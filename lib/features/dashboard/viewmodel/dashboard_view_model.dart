import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/health_metric.dart';
import '../../../core/utils/date_helpers.dart';
import '../../health_records/data/models/health_record.dart';
import '../../settings/data/daily_goals.dart';

/// Totals for one calendar day.
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

/// ViewModel for the dashboard.
///
/// It is *derived state*: Provider's `ProxyProvider2` rebuilds it from the
/// [HealthRecordViewModel] records and the [SettingsViewModel] goals
/// whenever either changes. All calculations are pure Dart, so they can
/// be unit tested without Flutter widgets or a database.
class DashboardViewModel {
  DashboardViewModel({
    required List<HealthRecord> records,
    required this.goals,
    DateTime? now,
  }) : today = DateHelpers.dateOnly(now ?? DateTime.now()) {
    _byDay = summariseByDay(records);
    todaySummary = _byDay[today] ?? DailySummary(date: today);
    last7Days = List.generate(AppConstants.chartDays, (i) {
      final day = DateTime(
        today.year,
        today.month,
        today.day - (AppConstants.chartDays - 1 - i),
      );
      return _byDay[day] ?? DailySummary(date: day);
    });
    streak = _calculateStreak();
    recentRecords = records.take(3).toList(growable: false);
    totalRecords = records.length;
  }

  final DateTime today;
  final DailyGoals goals;

  late final Map<DateTime, DailySummary> _byDay;

  /// Totals for today (the main dashboard numbers).
  late final DailySummary todaySummary;

  /// Oldest → newest, the last entry is today.
  late final List<DailySummary> last7Days;

  /// Consecutive days (ending today, or yesterday if nothing logged yet
  /// today) that have at least one entry.
  late final int streak;

  /// Up to three newest entries for the "Recent activity" section.
  late final List<HealthRecord> recentRecords;

  late final int totalRecords;

  /// Groups records into one [DailySummary] per day.
  static Map<DateTime, DailySummary> summariseByDay(
    List<HealthRecord> records,
  ) {
    final map = <DateTime, DailySummary>{};
    for (final r in records) {
      final day = DateHelpers.dateOnly(r.date);
      map[day] = (map[day] ?? DailySummary(date: day)).add(r);
    }
    return map;
  }

  int _calculateStreak() {
    var cursor = today;
    if (!(_byDay[cursor]?.hasData ?? false)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var count = 0;
    while (_byDay[cursor]?.hasData ?? false) {
      count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  /// Today's progress for one metric, between 0.0 and 1.0.
  double progressFor(HealthMetric metric) {
    final goal = goals.valueOf(metric);
    if (goal <= 0) return 0;
    return (todaySummary.valueOf(metric) / goal).clamp(0.0, 1.0);
  }

  /// Average progress across the three goals (hero card).
  double get overallProgress =>
      HealthMetric.values.map(progressFor).reduce((a, b) => a + b) /
      HealthMetric.values.length;

  /// Number of goals reached today (0-3).
  int get goalsCompleted =>
      HealthMetric.values.where((m) => progressFor(m) >= 1).length;

  /// Amount still needed to reach the goal today.
  int remainingFor(HealthMetric metric) {
    final remaining = goals.valueOf(metric) - todaySummary.valueOf(metric);
    return remaining < 0 ? 0 : remaining;
  }

  /// Average per *logged* day over the last 7 days.
  int weeklyAverage(HealthMetric metric) {
    final logged = last7Days.where((d) => d.hasData).toList();
    if (logged.isEmpty) return 0;
    final total = logged.fold<int>(0, (sum, d) => sum + d.valueOf(metric));
    return (total / logged.length).round();
  }

  /// Days in the last 7 on which the goal for [metric] was met.
  int daysGoalMet(HealthMetric metric) => last7Days
      .where((d) => d.valueOf(metric) >= goals.valueOf(metric))
      .length;

  /// Short motivational message based on today's progress.
  String get motivation {
    if (!todaySummary.hasData) {
      return 'No activity logged yet today. Let\'s get started!';
    }
    switch (goalsCompleted) {
      case 3:
        return 'Amazing! You reached all of today\'s goals.';
      case 2:
        return 'Great work – just one goal to go.';
      case 1:
        return 'Good start! Keep the momentum going.';
      default:
        return overallProgress >= 0.5
            ? 'You\'re over halfway there. Keep going!'
            : 'Every step counts. Keep moving!';
    }
  }
}
