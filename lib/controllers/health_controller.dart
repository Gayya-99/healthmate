import 'dart:collection';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/health_record.dart';

/// Date filters available on the record list screen.
enum RecordFilter { all, today, last7Days, thisMonth, specificDate, customRange }

/// CONTROLLER (MVC) – connects the views to the model and database.
///
/// * Holds the app state: records, active date filter, loading/error
///   state, daily goals and theme.
/// * Exposes CRUD actions that the views call.
/// * Calculates the dashboard summary (today's totals, progress, streak,
///   last 7 days).
/// * Extends [ChangeNotifier] and is provided with `Provider`; calling
///   [notifyListeners] rebuilds only the widgets that watch it.
class HealthController extends ChangeNotifier {
  HealthController(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DatabaseHelper _db;

  /// Injectable "now" so tests can use a fixed date.
  final DateTime Function() _clock;

  List<HealthRecord> _allRecords = const [];
  List<HealthRecord> _filteredRecords = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  RecordFilter _filter = RecordFilter.all;
  DateTimeRange? _filterRange;
  DailyGoals _goals = DailyGoals.defaults;
  ThemeMode _themeMode = ThemeMode.light;

  // =================================================================
  // State getters
  // =================================================================

  List<HealthRecord> get allRecords => UnmodifiableListView(_allRecords);

  /// Records after the active date filter (record list screen).
  List<HealthRecord> get visibleRecords => UnmodifiableListView(
        _filter == RecordFilter.all ? _allRecords : _filteredRecords,
      );

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  RecordFilter get filter => _filter;
  DateTimeRange? get filterRange => _filterRange;
  bool get isFiltering => _filter != RecordFilter.all;
  DailyGoals get goals => _goals;
  ThemeMode get themeMode => _themeMode;
  DateTime get today => DateUtil.dateOnly(_clock());

  /// Visible records grouped by day, newest day first.
  Map<DateTime, List<HealthRecord>> get groupedVisibleRecords {
    final groups = LinkedHashMap<DateTime, List<HealthRecord>>();
    for (final record in visibleRecords) {
      groups.putIfAbsent(record.date, () => []).add(record);
    }
    return groups;
  }

  String get filterLabel {
    final range = _filterRange;
    switch (_filter) {
      case RecordFilter.all:
        return 'All records';
      case RecordFilter.today:
        return 'Today';
      case RecordFilter.last7Days:
        return 'Last 7 days';
      case RecordFilter.thisMonth:
        return 'This month';
      case RecordFilter.specificDate:
        return range == null ? 'Date' : DateUtil.mediumDate(range.start);
      case RecordFilter.customRange:
        return range == null
            ? 'Custom range'
            : '${DateUtil.dayMonth(range.start)} – '
                '${DateUtil.dayMonth(range.end)}';
    }
  }

  // =================================================================
  // Loading
  // =================================================================

  /// Loads records and preferences from the database.
  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _goals = await _db.getGoals();
      _themeMode = _themeFromString(await _db.getThemeMode());
      _allRecords = await _db.getAllRecords();
      await _applyFilter();
    } catch (e) {
      _errorMessage = 'Could not load your records. Please try again.';
      debugPrint('loadData failed: $e');
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  // =================================================================
  // Search / filter by date
  // =================================================================

  Future<void> setFilter(
    RecordFilter filter, {
    DateTime? date,
    DateTimeRange? range,
  }) async {
    final now = today;
    switch (filter) {
      case RecordFilter.all:
        _filterRange = null;
        break;
      case RecordFilter.today:
        _filterRange = DateTimeRange(start: now, end: now);
        break;
      case RecordFilter.last7Days:
        _filterRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6),
          end: now,
        );
        break;
      case RecordFilter.thisMonth:
        _filterRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
        break;
      case RecordFilter.specificDate:
        final day = DateUtil.dateOnly(date ?? now);
        _filterRange = DateTimeRange(start: day, end: day);
        break;
      case RecordFilter.customRange:
        final r = range ?? DateTimeRange(start: now, end: now);
        _filterRange = DateTimeRange(
          start: DateUtil.dateOnly(r.start),
          end: DateUtil.dateOnly(r.end),
        );
        break;
    }
    _filter = filter;
    try {
      await _applyFilter();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Search failed. Please try again.';
      debugPrint('setFilter failed: $e');
    }
    notifyListeners();
  }

  Future<void> clearFilter() => setFilter(RecordFilter.all);

  Future<void> _applyFilter() async {
    final range = _filterRange;
    if (_filter == RecordFilter.all || range == null) {
      _filteredRecords = const [];
      return;
    }
    _filteredRecords = await _db.getRecordsInRange(range.start, range.end);
  }

  // =================================================================
  // CRUD
  // =================================================================

  /// Create – returns `true` on success.
  Future<bool> addRecord(HealthRecord record) =>
      _runCommand(() => _db.insertRecord(record), 'save the entry');

  /// Update – returns `true` on success.
  Future<bool> updateRecord(HealthRecord record) =>
      _runCommand(() => _db.updateRecord(record), 'update the entry');

  /// Delete – returns the deleted record so the UI can offer "Undo".
  Future<HealthRecord?> deleteRecord(int id) async {
    HealthRecord? deleted;
    for (final r in _allRecords) {
      if (r.id == id) {
        deleted = r;
        break;
      }
    }
    deleted ??= await _db.getRecordById(id);

    // Remove from the UI straight away (needed for swipe-to-delete).
    _allRecords = _allRecords.where((r) => r.id != id).toList();
    _filteredRecords = _filteredRecords.where((r) => r.id != id).toList();
    notifyListeners();

    final ok =
        await _runCommand(() => _db.deleteRecord(id), 'delete the entry');
    return ok ? deleted : null;
  }

  /// Puts back a record that was just deleted (same id).
  Future<bool> restoreRecord(HealthRecord record) =>
      _runCommand(() => _db.insertRecord(record), 'restore the entry');

  /// Adds water to today's latest entry, or creates one if none exists.
  Future<bool> quickAddWater(int ml) {
    return _runCommand(() async {
      final todays = await _db.getRecordsByDate(today);
      if (todays.isEmpty) {
        await _db.insertRecord(
          HealthRecord(date: today, steps: 0, calories: 0, water: ml),
        );
      } else {
        final latest = todays.first;
        await _db.updateRecord(latest.copyWith(water: latest.water + ml));
      }
    }, 'add water');
  }

  Future<bool> deleteAllRecords() =>
      _runCommand(_db.deleteAllRecords, 'delete all records');

  Future<bool> resetToSampleData() =>
      _runCommand(_db.resetToSampleData, 'load sample data');

  /// Runs a write action, then reloads so every screen updates.
  Future<bool> _runCommand(
    Future<Object?> Function() command,
    String action,
  ) async {
    try {
      await command();
      _errorMessage = null;
      _allRecords = await _db.getAllRecords();
      await _applyFilter();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Could not $action. Please try again.';
      debugPrint('$action failed: $e');
      notifyListeners();
      return false;
    }
  }

  // =================================================================
  // Goals & theme
  // =================================================================

  Future<void> updateGoal(HealthMetric metric, int value) async {
    _goals = _goals.copyWithMetric(metric, value);
    notifyListeners();
    await _db.saveGoals(_goals);
  }

  Future<void> resetGoals() async {
    _goals = DailyGoals.defaults;
    notifyListeners();
    await _db.saveGoals(_goals);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _db.saveThemeMode(mode.name);
  }

  static ThemeMode _themeFromString(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  // =================================================================
  // Dashboard summary
  // =================================================================

  /// Groups records into one [DailySummary] per day.
  static Map<DateTime, DailySummary> summariseByDay(
    Iterable<HealthRecord> records,
  ) {
    final map = <DateTime, DailySummary>{};
    for (final r in records) {
      final day = DateUtil.dateOnly(r.date);
      map[day] = (map[day] ?? DailySummary(date: day)).add(r);
    }
    return map;
  }

  Map<DateTime, DailySummary> get _byDay => summariseByDay(_allRecords);

  /// Totals for today (main dashboard numbers).
  DailySummary get todaySummary =>
      _byDay[today] ?? DailySummary(date: today);

  /// Last 7 days, oldest first – the last item is today.
  List<DailySummary> get last7Days {
    final byDay = _byDay;
    final now = today;
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day - (6 - i));
      return byDay[day] ?? DailySummary(date: day);
    });
  }

  /// Consecutive days with at least one entry, ending today (or yesterday
  /// if nothing has been logged yet today).
  int get streak {
    final byDay = _byDay;
    var cursor = today;
    if (!(byDay[cursor]?.hasData ?? false)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var count = 0;
    while (byDay[cursor]?.hasData ?? false) {
      count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  /// Today's progress for one metric (0.0 – 1.0).
  double progressFor(HealthMetric metric) {
    final goal = _goals.valueOf(metric);
    if (goal <= 0) return 0;
    return (todaySummary.valueOf(metric) / goal).clamp(0.0, 1.0);
  }

  /// Average progress across all three goals.
  double get overallProgress =>
      HealthMetric.values.map(progressFor).reduce((a, b) => a + b) /
      HealthMetric.values.length;

  /// Number of goals reached today (0 – 3).
  int get goalsCompleted =>
      HealthMetric.values.where((m) => progressFor(m) >= 1).length;

  /// Average per logged day over the last 7 days.
  int weeklyAverage(HealthMetric metric) {
    final logged = last7Days.where((d) => d.hasData).toList();
    if (logged.isEmpty) return 0;
    final total = logged.fold<int>(0, (sum, d) => sum + d.valueOf(metric));
    return (total / logged.length).round();
  }

  /// Days in the last 7 on which the goal was met.
  int daysGoalMet(HealthMetric metric) => last7Days
      .where((d) => d.valueOf(metric) >= _goals.valueOf(metric))
      .length;

  /// Up to three newest entries.
  List<HealthRecord> get recentRecords =>
      _allRecords.take(3).toList(growable: false);

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

/// Form validation rules used by the record form and goal dialog.
///
/// Pure functions, so they are easy to unit test.
class Validators {
  Validators._();

  static const int maxSteps = 100000;
  static const int maxCalories = 10000;
  static const int maxWater = 10000;

  static int maxFor(HealthMetric metric) {
    switch (metric) {
      case HealthMetric.steps:
        return maxSteps;
      case HealthMetric.calories:
        return maxCalories;
      case HealthMetric.water:
        return maxWater;
    }
  }

  /// One metric field. Empty is allowed (treated as 0); otherwise it must
  /// be a whole number between 0 and [max].
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
        return '$label must be ${NumberUtil.formatInt(max)} or less';
      }
      return null;
    };
  }

  /// A daily goal must be between 1 and [max].
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
        return 'Goal must be ${NumberUtil.formatInt(max)} or less';
      }
      return null;
    };
  }

  /// Form-level rule: at least one activity must be recorded.
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

  /// Entries cannot be for a future date.
  static String? notInFuture(DateTime? date, {DateTime? now}) {
    if (date == null) return 'Please choose a date';
    final t = now ?? DateTime.now();
    final endOfToday = DateTime(t.year, t.month, t.day, 23, 59, 59);
    if (date.isAfter(endOfToday)) return 'Date cannot be in the future';
    return null;
  }

  /// Empty text -> 0.
  static int parseOrZero(String? value) =>
      int.tryParse(value?.trim() ?? '') ?? 0;
}
