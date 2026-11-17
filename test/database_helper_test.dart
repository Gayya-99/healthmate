import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/database/database_helper.dart';
import 'package:healthmate/models/health_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests the real SQL in DatabaseHelper against an in-memory SQLite DB.
void main() {
  late DatabaseHelper db;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    db = DatabaseHelper.forTesting(factory: databaseFactoryFfiNoIsolate);
  });

  tearDown(() => db.close());

  HealthRecord entry(String date, {int steps = 1000}) => HealthRecord(
        date: DateUtil.fromDbString(date),
        steps: steps,
        calories: 100,
        water: 500,
      );

  test('insert then read back by id', () async {
    final id = await db.insertRecord(entry('2026-08-18', steps: 7850));
    final saved = await db.getRecordById(id);
    expect(saved?.steps, 7850);
    expect(DateUtil.toDbString(saved!.date), '2026-08-18');
  });

  test('getAllRecords is ordered newest date first', () async {
    await db.insertRecord(entry('2026-08-10'));
    await db.insertRecord(entry('2026-08-18'));
    await db.insertRecord(entry('2026-08-14'));
    final dates = (await db.getAllRecords())
        .map((r) => DateUtil.toDbString(r.date))
        .toList();
    expect(dates, ['2026-08-18', '2026-08-14', '2026-08-10']);
  });

  test('update changes the row', () async {
    final id = await db.insertRecord(entry('2026-08-18'));
    final changed = await db.updateRecord(
      entry('2026-08-18', steps: 5000).copyWith(id: id),
    );
    expect(changed, 1);
    expect((await db.getRecordById(id))?.steps, 5000);
  });

  test('delete removes the row', () async {
    final id = await db.insertRecord(entry('2026-08-18'));
    expect(await db.deleteRecord(id), 1);
    expect(await db.getRecordById(id), isNull);
  });

  test('search by date and by date range', () async {
    await db.insertRecord(entry('2026-08-01'));
    await db.insertRecord(entry('2026-08-12'));
    await db.insertRecord(entry('2026-08-18'));
    await db.insertRecord(entry('2026-08-18'));

    expect((await db.getRecordsByDate(DateTime(2026, 8, 18))).length, 2);
    final range = await db.getRecordsInRange(
      DateTime(2026, 8, 12),
      DateTime(2026, 8, 18),
    );
    expect(range.length, 3);
  });

  test('goals and theme are saved in app_settings', () async {
    expect(await db.getThemeMode(), 'light');
    await db.saveThemeMode('dark');
    expect(await db.getThemeMode(), 'dark');

    await db.saveGoals(const DailyGoals(steps: 8000, calories: 400, water: 2000));
    expect((await db.getGoals()).steps, 8000);
  });

  test('sample data creates 7 records', () async {
    final seeded = DatabaseHelper.forTesting(
      factory: databaseFactoryFfiNoIsolate,
      seedSampleData: true,
    );
    expect((await seeded.getAllRecords()).length, 7);
    await seeded.close();
  });
}
