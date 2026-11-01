import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/features/health_records/data/models/health_record.dart';
import 'package:healthmate/features/health_records/data/repositories/in_memory_health_record_repository.dart';
import 'package:healthmate/features/health_records/viewmodel/health_record_view_model.dart';

void main() {
  final fixedNow = DateTime(2026, 8, 18, 10);
  late HealthRecordViewModel vm;

  setUp(() async {
    final repo = InMemoryHealthRecordRepository(
      seedSampleData: false,
      latency: Duration.zero,
    );
    vm = HealthRecordViewModel(repo, clock: () => fixedNow);
    await vm.loadRecords();
  });

  HealthRecord entry(int day, {int steps = 1000, int water = 500}) =>
      HealthRecord(
        date: DateTime(2026, 8, day),
        steps: steps,
        calories: 100,
        water: water,
      );

  test('Create: addRecord stores the record with a new id', () async {
    expect(await vm.addRecord(entry(18)), isTrue);
    expect(vm.allRecords.length, 1);
    expect(vm.allRecords.first.id, isNotNull);
  });

  test('Read: records are sorted newest date first', () async {
    await vm.addRecord(entry(10));
    await vm.addRecord(entry(18));
    await vm.addRecord(entry(14));
    expect(
      vm.allRecords.map((r) => r.date.day).toList(),
      [18, 14, 10],
    );
  });

  test('Update: updateRecord changes the stored values', () async {
    await vm.addRecord(entry(18));
    final saved = vm.allRecords.first;
    await vm.updateRecord(saved.copyWith(steps: 9999));
    expect(vm.allRecords.first.steps, 9999);
  });

  test('Delete + Undo: deleteRecord removes and restoreRecord brings back',
      () async {
    await vm.addRecord(entry(18));
    final id = vm.allRecords.first.id!;
    final deleted = await vm.deleteRecord(id);
    expect(vm.allRecords, isEmpty);
    await vm.restoreRecord(deleted!);
    expect(vm.allRecords.single.id, id);
  });

  test('Search: specific date filter returns only that day', () async {
    await vm.addRecord(entry(17));
    await vm.addRecord(entry(18));
    await vm.addRecord(entry(18));
    await vm.setFilter(RecordFilter.specificDate, date: DateTime(2026, 8, 18));
    expect(vm.visibleRecords.length, 2);
    expect(vm.visibleRecords.every((r) => r.date.day == 18), isTrue);
  });

  test('Filter: last 7 days excludes older records', () async {
    await vm.addRecord(entry(1));
    await vm.addRecord(entry(12));
    await vm.addRecord(entry(18));
    await vm.setFilter(RecordFilter.last7Days);
    expect(vm.visibleRecords.map((r) => r.date.day), [18, 12]);
    await vm.clearFilter();
    expect(vm.visibleRecords.length, 3);
  });

  test('quickAddWater adds to today\'s latest entry', () async {
    await vm.addRecord(entry(18, water: 500));
    await vm.quickAddWater(250);
    expect(vm.allRecords.single.water, 750);
  });

  test('quickAddWater creates an entry when today is empty', () async {
    await vm.quickAddWater(500);
    expect(vm.allRecords.single.water, 500);
    expect(vm.allRecords.single.steps, 0);
  });
}
