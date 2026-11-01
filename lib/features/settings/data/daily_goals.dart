import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/health_metric.dart';

/// The user's daily targets, used to calculate dashboard progress.
@immutable
class DailyGoals {
  const DailyGoals({
    this.steps = AppConstants.defaultStepsGoal,
    this.calories = AppConstants.defaultCaloriesGoal,
    this.water = AppConstants.defaultWaterGoalMl,
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
