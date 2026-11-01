import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/features/health_records/data/models/health_record.dart';

void main() {
  final record = HealthRecord(
    id: 1,
    date: DateTime(2026, 8, 18),
    steps: 7850,
    calories: 420,
    water: 2000,
  );

  test('toMap stores the date as yyyy-MM-dd text', () {
    expect(record.toMap(), {
      'id': 1,
      'date': '2026-08-18',
      'steps': 7850,
      'calories': 420,
      'water': 2000,
    });
  });

  test('fromMap(toMap()) returns an equal record', () {
    expect(HealthRecord.fromMap(record.toMap()), record);
  });

  test('toMap omits id for a new record', () {
    final newRecord = HealthRecord(
      date: DateTime(2026, 8, 18),
      steps: 100,
      calories: 10,
      water: 250,
    );
    expect(newRecord.toMap().containsKey('id'), isFalse);
  });

  test('copyWith changes only the given fields', () {
    final updated = record.copyWith(water: 2500);
    expect(updated.water, 2500);
    expect(updated.steps, 7850);
    expect(updated.id, 1);
  });
}
