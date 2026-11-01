import 'dart:math';

import '../../../core/utils/date_helpers.dart';
import 'models/health_record.dart';

/// Dummy records so the app has realistic content on first launch.
///
/// Data is generated relative to "today" so the dashboard, weekly chart
/// and date filters always have something to show. A fixed random seed
/// keeps the values the same every launch, which makes testing repeatable.
class SampleData {
  SampleData._();

  static const int daysOfHistory = 21;

  /// Builds the list of sample records ending on [today] (without ids).
  static List<HealthRecord> generate({DateTime? today}) {
    final now = DateHelpers.dateOnly(today ?? DateTime.now());
    final random = Random(2026);
    final records = <HealthRecord>[];

    // Today: a partly completed day so the progress rings are visible.
    records.add(HealthRecord(date: now, steps: 4250, calories: 210, water: 750));
    records.add(HealthRecord(date: now, steps: 1830, calories: 95, water: 500));

    // Previous days. Two days are skipped so the streak looks realistic.
    for (var i = 1; i <= daysOfHistory; i++) {
      if (i == 9 || i == 16) continue;
      final day = DateTime(now.year, now.month, now.day - i);
      final entries = random.nextInt(3) == 0 ? 2 : 1;
      for (var e = 0; e < entries; e++) {
        final steps = 2500 + random.nextInt(entries == 1 ? 9000 : 5000);
        records.add(
          HealthRecord(
            date: day,
            steps: steps,
            // Roughly 45-55 kcal per 1,000 steps plus some variation.
            calories: (steps * (0.045 + random.nextDouble() * 0.01)).round() +
                random.nextInt(60),
            water: (entries == 1 ? 1500 : 750) + random.nextInt(5) * 250,
          ),
        );
      }
    }
    return records;
  }
}
