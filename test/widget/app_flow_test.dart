import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/app.dart';
import 'package:healthmate/features/health_records/data/repositories/in_memory_health_record_repository.dart';
import 'package:healthmate/features/settings/data/settings_repository.dart';

Widget buildApp() => HealthMateApp(
      recordRepository: InMemoryHealthRecordRepository(
        seedSampleData: false,
        latency: Duration.zero,
      ),
      settingsRepository: InMemorySettingsRepository(),
    );

void main() {
  testWidgets('Dashboard shows today\'s date and empty totals',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Today –'), findsOneWidget);
    expect(find.text('Steps'), findsWidgets);
    expect(find.byKey(const ValueKey('today-steps')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('today-steps'))).data,
      '0',
    );
  });

  testWidgets('Saving an empty form shows a validation error',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-entry-fab')));
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey('save-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Enter at least one value greater than 0'),
        findsOneWidget);
  });

  testWidgets('Value above the limit is rejected', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-entry-fab')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('field-steps')), '200000');
    final save = find.byKey(const ValueKey('save-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Steps must be 100,000 or less'), findsOneWidget);
  });

  testWidgets('Adding an entry updates the dashboard totals',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-entry-fab')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('field-steps')), '7850');
    await tester.enterText(find.byKey(const ValueKey('field-water')), '2000');
    final save = find.byKey(const ValueKey('save-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('today-steps'))).data,
      '7,850',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('today-water'))).data,
      '2,000',
    );
  });
}
