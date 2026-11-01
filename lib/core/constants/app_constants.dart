/// Application-wide constants (limits, defaults and labels).
///
/// Keeping these values in one place means the form validation, the
/// database seed data and the UI all agree on the same rules.
class AppConstants {
  AppConstants._();

  static const String appName = 'HealthMate';
  static const String appTagline = 'Personal Health & Wellness Tracker';
  static const String appVersion = '1.0.0';

  // Upper limits used by form validation (sensible single-entry maximums).
  static const int maxSteps = 100000;
  static const int maxCalories = 10000;
  static const int maxWaterMl = 10000;

  // Default daily goals (can be changed by the user in Settings).
  static const int defaultStepsGoal = 10000;
  static const int defaultCaloriesGoal = 500;
  static const int defaultWaterGoalMl = 2500;

  // Maximum value a goal can be set to.
  static const int maxStepsGoal = 100000;
  static const int maxCaloriesGoal = 10000;
  static const int maxWaterGoalMl = 10000;

  /// Amounts offered by the "quick add water" buttons (ml).
  static const List<int> quickWaterAmounts = [250, 500];

  /// Number of days shown in the weekly chart.
  static const int chartDays = 7;
}
