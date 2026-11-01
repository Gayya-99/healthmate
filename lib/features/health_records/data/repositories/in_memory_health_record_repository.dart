import '../../../../core/utils/date_helpers.dart';
import '../models/health_record.dart';
import '../sample_data.dart';
import 'health_record_repository.dart';

/// Stores records in a list in memory (frontend-only build).
///
/// It behaves like a real database table: it auto-increments ids, returns
/// records newest first and supports date-range queries. Data resets when
/// the app restarts. To move to SQLite later, create a class that
/// implements [HealthRecordRepository] with sqflite and pass it to the app
/// in `main.dart` – nothing in the UI or view models needs to change.
class InMemoryHealthRecordRepository implements HealthRecordRepository {
  InMemoryHealthRecordRepository({
    bool seedSampleData = true,
    DateTime? today,
    this.latency = const Duration(milliseconds: 120),
  }) {
    if (seedSampleData) _seed(today);
  }

  /// Small artificial delay so loading states behave like a real database.
  /// Tests pass `Duration.zero`.
  final Duration latency;

  final List<HealthRecord> _records = [];
  int _nextId = 1;

  void _seed(DateTime? today) {
    for (final r in SampleData.generate(today: today)) {
      _records.add(r.copyWith(id: _nextId++));
    }
  }

  Future<void> _delay() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  /// Newest day first; within a day, the most recently added entry first.
  List<HealthRecord> _sorted(Iterable<HealthRecord> items) {
    final list = items.toList();
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
    });
    return list;
  }

  @override
  Future<List<HealthRecord>> getAllRecords() async {
    await _delay();
    return _sorted(_records);
  }

  @override
  Future<HealthRecord?> getRecordById(int id) async {
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<List<HealthRecord>> getRecordsByDate(DateTime date) async {
    return _sorted(_records.where((r) => DateHelpers.isSameDay(r.date, date)));
  }

  @override
  Future<List<HealthRecord>> getRecordsInRange(
    DateTime start,
    DateTime end,
  ) async {
    await _delay();
    final from = DateHelpers.dateOnly(start);
    final to = DateHelpers.dateOnly(end);
    return _sorted(
      _records.where((r) => !r.date.isBefore(from) && !r.date.isAfter(to)),
    );
  }

  @override
  Future<int> insertRecord(HealthRecord record) async {
    await _delay();
    final id = record.id ?? _nextId++;
    if (id >= _nextId) _nextId = id + 1;
    _records.removeWhere((r) => r.id == id); // "replace" on conflict
    _records.add(record.copyWith(id: id, date: DateHelpers.dateOnly(record.date)));
    return id;
  }

  @override
  Future<int> updateRecord(HealthRecord record) async {
    if (record.id == null) {
      throw ArgumentError('Cannot update a record without an id');
    }
    await _delay();
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index == -1) return 0;
    _records[index] = record.copyWith(date: DateHelpers.dateOnly(record.date));
    return 1;
  }

  @override
  Future<int> deleteRecord(int id) async {
    await _delay();
    final before = _records.length;
    _records.removeWhere((r) => r.id == id);
    return before - _records.length;
  }

  @override
  Future<void> deleteAllRecords() async {
    await _delay();
    _records.clear();
  }

  @override
  Future<void> resetToSampleData() async {
    await _delay();
    _records.clear();
    _nextId = 1;
    _seed(null);
  }
}
