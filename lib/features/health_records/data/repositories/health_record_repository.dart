import '../models/health_record.dart';

/// Contract for reading and writing health records.
///
/// The view model depends on this abstraction, not on a storage technology.
/// The app currently uses [InMemoryHealthRecordRepository]. A SQLite (sqflite)
/// implementation can be added later without changing any UI code. This is
/// the "Model" side of MVVM.
abstract class HealthRecordRepository {
  /// All records, newest date first.
  Future<List<HealthRecord>> getAllRecords();

  /// A single record by primary key, or `null` if it does not exist.
  Future<HealthRecord?> getRecordById(int id);

  /// Records for one calendar day.
  Future<List<HealthRecord>> getRecordsByDate(DateTime date);

  /// Records between [start] and [end] (both inclusive), newest first.
  Future<List<HealthRecord>> getRecordsInRange(DateTime start, DateTime end);

  /// Inserts a record and returns its new id. If the record already has an
  /// id (e.g. "undo delete") that id is reused.
  Future<int> insertRecord(HealthRecord record);

  /// Updates an existing record. Returns the number of rows changed.
  Future<int> updateRecord(HealthRecord record);

  /// Deletes a record. Returns the number of rows removed.
  Future<int> deleteRecord(int id);

  /// Removes every record.
  Future<void> deleteAllRecords();

  /// Replaces all records with freshly generated dummy data.
  Future<void> resetToSampleData();
}
