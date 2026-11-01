import 'daily_goals.dart';

/// Stores user preferences (daily goals and theme).
abstract class SettingsRepository {
  Future<DailyGoals> loadGoals();
  Future<void> saveGoals(DailyGoals goals);

  /// One of `system`, `light` or `dark`.
  Future<String> loadThemePreference();
  Future<void> saveThemePreference(String value);
}

/// Keeps preferences in memory for the frontend-only build.
///
/// Can later be replaced by a SQLite or shared_preferences implementation
/// without changing the settings view model or screen.
class InMemorySettingsRepository implements SettingsRepository {
  DailyGoals _goals = DailyGoals.defaults;
  String _theme = 'system';

  @override
  Future<DailyGoals> loadGoals() async => _goals;

  @override
  Future<void> saveGoals(DailyGoals goals) async {
    _goals = goals;
  }

  @override
  Future<String> loadThemePreference() async => _theme;

  @override
  Future<void> saveThemePreference(String value) async {
    _theme = value;
  }
}
