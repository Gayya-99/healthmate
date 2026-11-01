import 'dart:collection';

import 'package:flutter/material.dart';

import '../../../core/utils/date_helpers.dart';
import '../data/models/health_record.dart';
import '../data/repositories/health_record_repository.dart';

/// Date filters available on the Records screen.
enum RecordFilter { all, today, last7Days, thisMonth, specificDate, customRange }

/// ViewModel (MVVM) for everything related to health records.
///
/// * Holds UI state: the record list, loading flag, error message and the
///   active date filter.
/// * Exposes CRUD commands that the views call.
/// * Talks to the database only through [HealthRecordRepository].
/// * Calls [notifyListeners] after every state change so Provider rebuilds
///   only the widgets that depend on this view model.
class HealthRecordViewModel extends ChangeNotifier {
  HealthRecordViewModel(this._repository, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final HealthRecordRepository _repository;

  /// Injectable "current time" so tests can use a fixed date.
  final DateTime Function() _clock;

  List<HealthRecord> _allRecords = const [];
  List<HealthRecord> _filteredRecords = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  RecordFilter _filter = RecordFilter.all;
  DateTimeRange? _filterRange;

  // ------------------------------------------------------------ getters --

  /// Every record (used by the dashboard).
  List<HealthRecord> get allRecords => UnmodifiableListView(_allRecords);

  /// Records after the active date filter is applied (Records screen).
  List<HealthRecord> get visibleRecords => UnmodifiableListView(
        _filter == RecordFilter.all ? _allRecords : _filteredRecords,
      );

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  RecordFilter get filter => _filter;
  DateTimeRange? get filterRange => _filterRange;
  bool get isFiltering => _filter != RecordFilter.all;
  DateTime get today => DateHelpers.dateOnly(_clock());

  /// Visible records grouped by day, newest day first.
  Map<DateTime, List<HealthRecord>> get groupedVisibleRecords {
    final groups = LinkedHashMap<DateTime, List<HealthRecord>>();
    for (final record in visibleRecords) {
      groups.putIfAbsent(record.date, () => []).add(record);
    }
    return groups;
  }

  /// Human readable description of the active filter.
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
        return range == null ? 'Date' : DateHelpers.mediumDate(range.start);
      case RecordFilter.customRange:
        return range == null
            ? 'Custom range'
            : '${DateHelpers.dayMonth(range.start)} – '
                '${DateHelpers.dayMonth(range.end)}';
    }
  }

  // ------------------------------------------------------------- loading --

  Future<void> loadRecords() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _allRecords = await _repository.getAllRecords();
      await _applyFilter();
    } catch (e) {
      _errorMessage = 'Could not load your records. Please try again.';
      debugPrint('loadRecords failed: $e');
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  // ---------------------------------------------------- search / filter --

  /// Changes the date filter. [date] is used for [RecordFilter.specificDate]
  /// and [range] for [RecordFilter.customRange].
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
        final day = DateHelpers.dateOnly(date ?? now);
        _filterRange = DateTimeRange(start: day, end: day);
        break;
      case RecordFilter.customRange:
        final r = range ?? DateTimeRange(start: now, end: now);
        _filterRange = DateTimeRange(
          start: DateHelpers.dateOnly(r.start),
          end: DateHelpers.dateOnly(r.end),
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

  /// Runs the date search in SQLite (`WHERE date BETWEEN ? AND ?`).
  Future<void> _applyFilter() async {
    final range = _filterRange;
    if (_filter == RecordFilter.all || range == null) {
      _filteredRecords = const [];
      return;
    }
    _filteredRecords =
        await _repository.getRecordsInRange(range.start, range.end);
  }

  // ---------------------------------------------------------------- CRUD --

  /// Create. Returns `true` on success.
  Future<bool> addRecord(HealthRecord record) =>
      _runCommand(() => _repository.insertRecord(record), 'save the entry');

  /// Update. Returns `true` on success.
  Future<bool> updateRecord(HealthRecord record) =>
      _runCommand(() => _repository.updateRecord(record), 'update the entry');

  /// Delete. Returns the deleted record so the UI can offer "Undo".
  Future<HealthRecord?> deleteRecord(int id) async {
    HealthRecord? deleted;
    for (final r in _allRecords) {
      if (r.id == id) {
        deleted = r;
        break;
      }
    }
    deleted ??= await _repository.getRecordById(id);

    // Optimistic update: remove from the UI immediately (needed for
    // swipe-to-delete), then persist. On failure the reload restores it.
    _allRecords = _allRecords.where((r) => r.id != id).toList();
    _filteredRecords = _filteredRecords.where((r) => r.id != id).toList();
    notifyListeners();

    final ok = await _runCommand(
      () => _repository.deleteRecord(id),
      'delete the entry',
    );
    if (!ok) {
      try {
        await _reload();
      } catch (_) {}
    }
    return ok ? deleted : null;
  }

  /// Re-inserts a record that was just deleted (keeps the same id).
  Future<bool> restoreRecord(HealthRecord record) =>
      _runCommand(() => _repository.insertRecord(record), 'restore the entry');

  /// Quick-add water from the dashboard. The amount is added to today's
  /// most recent entry; if there is no entry today a new one is created.
  Future<bool> quickAddWater(int ml) {
    return _runCommand(() async {
      final todays = await _repository.getRecordsByDate(today);
      if (todays.isEmpty) {
        await _repository.insertRecord(
          HealthRecord(date: today, steps: 0, calories: 0, water: ml),
        );
      } else {
        final latest = todays.first;
        await _repository.updateRecord(
          latest.copyWith(water: latest.water + ml),
        );
      }
    }, 'add water');
  }

  Future<bool> deleteAllRecords() =>
      _runCommand(_repository.deleteAllRecords, 'clear records');

  Future<bool> resetToSampleData() =>
      _runCommand(_repository.resetToSampleData, 'load sample data');

  /// Runs a write operation, then reloads data so every screen updates.
  Future<bool> _runCommand(
    Future<Object?> Function() command,
    String action,
  ) async {
    try {
      await command();
      _errorMessage = null;
      await _reload();
      return true;
    } catch (e) {
      _errorMessage = 'Could not $action. Please try again.';
      debugPrint('$action failed: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> _reload() async {
    _allRecords = await _repository.getAllRecords();
    await _applyFilter();
    notifyListeners();
  }
}
