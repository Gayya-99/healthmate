import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/controllers/health_controller.dart';

void main() {
  group('Validators.metric', () {
    final validate = Validators.metric(label: 'Steps', max: 100000);

    test('empty value is allowed (treated as 0)', () {
      expect(validate(''), isNull);
      expect(validate(null), isNull);
    });

    test('accepts a valid whole number', () {
      expect(validate('7850'), isNull);
    });

    test('rejects text that is not a whole number', () {
      expect(validate('abc'), 'Enter a whole number');
      expect(validate('12.5'), 'Enter a whole number');
    });

    test('rejects negative numbers', () {
      expect(validate('-5'), 'Steps cannot be negative');
    });

    test('rejects values above the maximum', () {
      expect(validate('100001'), 'Steps must be 100,000 or less');
    });
  });

  test('atLeastOneValue fails when every value is 0', () {
    expect(
      Validators.atLeastOneValue(steps: 0, calories: 0, water: 0),
      'Enter at least one value greater than 0',
    );
    expect(Validators.atLeastOneValue(steps: 0, calories: 0, water: 250), isNull);
  });

  test('goal must be greater than 0', () {
    final validate = Validators.goal(label: 'Water', max: 10000);
    expect(validate(''), 'Water goal is required');
    expect(validate('0'), 'Goal must be greater than 0');
    expect(validate('2500'), isNull);
  });

  test('notInFuture rejects tomorrow and accepts today', () {
    final now = DateTime(2026, 8, 18, 10);
    expect(Validators.notInFuture(DateTime(2026, 8, 18), now: now), isNull);
    expect(
      Validators.notInFuture(DateTime(2026, 8, 19), now: now),
      'Date cannot be in the future',
    );
  });
}
