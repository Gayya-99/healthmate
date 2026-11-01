import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/core/constants/health_metric.dart';
import 'package:healthmate/features/dashboard/viewmodel/dashboard_view_model.dart';
import 'package:healthmate/features/health_records/data/models/health_record.dart';
import 'package:healthmate/features/settings/data/daily_goals.dart';

void main() {
  final today = DateTime(2026, 8, 18, 9, 30);
  DateTime day(int offset) => DateTime(2026, 8, 18 - offset);

  final records = [
    HealthRecord(id: 1, date: day(0), steps: 5000, calories: 300, water: 1000),
    HealthRecord(id: 2, date: day(0), steps: 2850, calories: 120, water: 1000),
    HealthRecord(id: 3, date: day(1), steps: 9000, calories: 450, water: 2500),
    HealthRecord(id: 4, date: day(2), steps: 11000, calories: 520, water: 2600),
    // day(3) missing -> streak stops here
    HealthRecord(id: 5, date: day(4), steps: 4000, calories: 200, water: 1500),
  ];

  const goals = DailyGoals(steps: 10000, calories: 500, water: 2000);

  DashboardViewModel build(List<HealthRecord> r) =>
      DashboardViewModel(records: r, goals: goals, now: today);

  test('sums all of today\'s entries', () {
    final vm = build(records);
    expect(vm.todaySummary.steps, 7850);
    expect(vm.todaySummary.calories, 420);
    expect(vm.todaySummary.water, 2000);
    expect(vm.todaySummary.entryCount, 2);
  });

  test('progress is capped at 100%', () {
    final vm = build(records);
    expect(vm.progressFor(HealthMetric.water), 1.0);
    expect(vm.progressFor(HealthMetric.steps), closeTo(0.785, 0.001));
    expect(vm.goalsCompleted, 1);
  });

  test('streak counts consecutive days ending today', () {
    expect(build(records).streak, 3);
  });

  test('streak continues from yesterday when nothing logged today', () {
    final withoutToday = records.where((r) => r.date != day(0)).toList();
    expect(build(withoutToday).streak, 2);
  });

  test('last7Days has 7 days, oldest first, ending today', () {
    final vm = build(records);
    expect(vm.last7Days.length, 7);
    expect(vm.last7Days.last.date, day(0));
    expect(vm.last7Days.first.date, day(6));
  });

  test('weekly average only counts days with data', () {
    final vm = build(records);
    // (7850 + 9000 + 11000 + 4000) / 4 days
    expect(vm.weeklyAverage(HealthMetric.steps), 7963);
    expect(vm.daysGoalMet(HealthMetric.steps), 1);
  });

  test('empty data gives zero values and a friendly message', () {
    final vm = build(const []);
    expect(vm.todaySummary.hasData, isFalse);
    expect(vm.overallProgress, 0);
    expect(vm.streak, 0);
    expect(vm.motivation, contains('No activity'));
  });
}
