import 'package:flutter/material.dart';

import '../../../core/constants/health_metric.dart';
import '../data/daily_goals.dart';
import '../data/settings_repository.dart';

/// Holds user preferences and exposes them to the UI.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._repository);

  final SettingsRepository _repository;

  DailyGoals _goals = DailyGoals.defaults;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoaded = false;

  DailyGoals get goals => _goals;
  ThemeMode get themeMode => _themeMode;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    try {
      _goals = await _repository.loadGoals();
      _themeMode = _themeFromString(await _repository.loadThemePreference());
    } catch (_) {
      // Fall back to defaults – preferences are not critical data.
      _goals = DailyGoals.defaults;
      _themeMode = ThemeMode.system;
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateGoal(HealthMetric metric, int value) async {
    _goals = _goals.copyWithMetric(metric, value);
    notifyListeners(); // optimistic update – UI responds instantly
    await _repository.saveGoals(_goals);
  }

  Future<void> resetGoals() async {
    _goals = DailyGoals.defaults;
    notifyListeners();
    await _repository.saveGoals(_goals);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _repository.saveThemePreference(mode.name);
  }

  static ThemeMode _themeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
