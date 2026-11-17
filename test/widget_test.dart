import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/database/database_helper.dart';
import 'package:healthmate/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget buildApp() => HealthMateApp(
      database: DatabaseHelper.forTesting(factory: databaseFactoryFfiNoIsolate),
    );

Future<void> openForm(WidgetTester tester) async {
  await tester.pumpWidget(buildApp());
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('add-entry-fab')));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('save-button'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

String todayValue(WidgetTester tester, String metric) =>
    tester.widget<Text>(find.byKey(ValueKey('today-$metric'))).data!;

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('Dashboard shows today\'s date and zero totals', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Today –'), findsOneWidget);
    expect(todayValue(tester, 'steps'), '0');
  });

  testWidgets('Empty form shows a validation error', (tester) async {
    await openForm(tester);
    await tapSave(tester);
    expect(find.text('Enter at least one value greater than 0'), findsOneWidget);
  });

  testWidgets('Value above the limit is rejected', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byKey(const ValueKey('field-steps')), '200000');
    await tapSave(tester);
    expect(find.text('Steps must be 100,000 or less'), findsOneWidget);
  });

  testWidgets('Adding an entry updates the dashboard', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byKey(const ValueKey('field-steps')), '7850');
    await tester.enterText(find.byKey(const ValueKey('field-water')), '2000');
    await tapSave(tester);
    expect(todayValue(tester, 'steps'), '7,850');
    expect(todayValue(tester, 'water'), '2,000');
  });
}
