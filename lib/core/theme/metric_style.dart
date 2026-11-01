import 'package:flutter/material.dart';

import '../constants/health_metric.dart';

/// Visual identity of each metric (colour, icon, label, unit).
///
/// Using one consistent colour per metric everywhere in the app helps the
/// user recognise data at a glance: steps = green, calories = red,
/// water = blue (as suggested in the coursework brief).
class MetricStyle {
  const MetricStyle({
    required this.label,
    required this.shortLabel,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final String shortLabel;
  final String unit;
  final IconData icon;
  final Color color;

  static const Color stepsColor = Color(0xFF2E9E5B);
  static const Color caloriesColor = Color(0xFFE5484D);
  static const Color waterColor = Color(0xFF2F80ED);

  static const MetricStyle steps = MetricStyle(
    label: 'Steps',
    shortLabel: 'Steps',
    unit: 'steps',
    icon: Icons.directions_walk_rounded,
    color: stepsColor,
  );

  static const MetricStyle calories = MetricStyle(
    label: 'Calories Burned',
    shortLabel: 'Calories',
    unit: 'kcal',
    icon: Icons.local_fire_department_rounded,
    color: caloriesColor,
  );

  static const MetricStyle water = MetricStyle(
    label: 'Water Intake',
    shortLabel: 'Water',
    unit: 'ml',
    icon: Icons.water_drop_rounded,
    color: waterColor,
  );

  static MetricStyle of(HealthMetric metric) {
    switch (metric) {
      case HealthMetric.steps:
        return steps;
      case HealthMetric.calories:
        return calories;
      case HealthMetric.water:
        return water;
    }
  }
}
