import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/controllers/health_controller.dart';
import 'package:healthmate/database/database_helper.dart';
import 'package:healthmate/models/health_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final fixedNow = DateTime(2026, 8, 18, 10);
  late DatabaseHelper db;
  late HealthController controller;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = DatabaseHelper.forTesting(factory: databaseFactoryFfiNoIsolate);
    controller = HealthController(db, clock: () => fixedNow);
    await controller.loadData();
  });

  tearDown(() => db.close());

  HealthRecord entry(int day, {int steps = 1000, int calories = 100, int water = 500}) =>
      HealthRecord(
        date: DateTime(2026, 8, day),
        steps: steps,
        calories: calories,
        water: water,
      );

  group('CRUD', () {
    test('Create: addRecord stores the record with a new id', () async {
      expect(await controller.addRecord(entry(18)), isTrue);
      expect(controller.allRecords.length, 1);
      expect(controller.allRecords.first.id, isNotNull);
    });

    test('Read: records are listed newest date first', () async {
      await controller.addRecord(entry(10));
      await controller.addRecord(entry(18));
      await controller.addRecord(entry(14));
      expect(controller.allRecords.map((r) => r.date.day).toList(), [18, 14, 10]);
    });

    test('Update: updateRecord changes the stored values', () async {
      await controller.addRecord(entry(18));
      final saved = controller.allRecords.first;
      await controller.updateRecord(saved.copyWith(steps: 9999));
      expect(controller.allRecords.first.steps, 9999);
    });

    test('Delete + Undo', () async {
      await controller.addRecord(entry(18));
      final id = controller.allRecords.first.id!;
      final deleted = await controller.deleteRecord(id);
      expect(controller.allRecords, isEmpty);
      await controller.restoreRecord(deleted!);
      expect(controller.allRecords.single.id, id);
    });
  });

  group('Search / filter', () {
    test('specific date returns only that day', () async {
      await controller.addRecord(entry(17));
      await controller.addRecord(entry(18));
      await controller.addRecord(entry(18));
      await controller.setFilter(
        RecordFilter.specificDate,
        date: DateTime(2026, 8, 18),
      );
      expect(controller.visibleRecords.length, 2);
    });

    test('last 7 days excludes older records; clear shows all', () async {
      await controller.addRecord(entry(1));
      await controller.addRecord(entry(12));
      await controller.addRecord(entry(18));
      await controller.setFilter(RecordFilter.last7Days);
      expect(controller.visibleRecords.map((r) => r.date.day), [18, 12]);
      await controller.clearFilter();
      expect(controller.visibleRecords.length, 3);
    });
  });

  group('Dashboard', () {
    test('sums all of today\'s entries', () async {
      await controller.addRecord(entry(18, steps: 5000, calories: 300, water: 1000));
      await controller.addRecord(entry(18, steps: 2850, calories: 120, water: 1000));
      expect(controller.todaySummary.steps, 7850);
      expect(controller.todaySummary.calories, 420);
      expect(controller.todaySummary.water, 2000);
    });

    test('progress is capped at 100%', () async {
      await controller.addRecord(entry(18, water: 9000));
      expect(controller.progressFor(HealthMetric.water), 1.0);
    });

    test('streak counts consecutive days', () async {
      await controller.addRecord(entry(18));
      await controller.addRecord(entry(17));
      await controller.addRecord(entry(16));
      await controller.addRecord(entry(14)); // gap on the 15th
      expect(controller.streak, 3);
    });

    test('last7Days has 7 days ending today', () {
      final days = controller.last7Days;
      expect(days.length, 7);
      expect(days.last.date, DateTime(2026, 8, 18));
      expect(days.first.date, DateTime(2026, 8, 12));
    });

    test('quickAddWater adds to today\'s latest entry', () async {
      await controller.addRecord(entry(18, water: 500));
      await controller.quickAddWater(250);
      expect(controller.allRecords.single.water, 750);
    });
  });
}
