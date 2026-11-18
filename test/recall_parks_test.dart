import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_portable/models/activity_ref.dart';
import 'package:wavelog_portable/services/settings_service.dart';
import 'package:wavelog_portable/widgets/activity_selection_dialog.dart';

final usA = ActivityRef(type: 'POTA', reference: 'US-1234', name: 'Park A');
final usB = ActivityRef(type: 'POTA', reference: 'US-10456', name: 'Park B');

/// Opens the dialog over a plain app, as the details screen does.
Future<void> _openDialog(WidgetTester tester, List<ActivityRef> selected) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDialog<List<ActivityRef>>(
          context: context,
          builder: (_) => ActivitySelectionDialog(selected: selected),
        ),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  test('last parks round-trip through settings', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AppSettings.getLastActivities(), isEmpty);
    await AppSettings.saveLastActivities([usA, usB]);
    final back = await AppSettings.getLastActivities();
    expect(back.map((r) => r.reference), ['US-1234', 'US-10456']);
    expect(back.first.name, 'Park A');
    expect(back.first.type, 'POTA');
  });

  test('corrupt stored value is ignored', () async {
    SharedPreferences.setMockInitialValues({AppSettings.keyLastActivities: 'not json'});
    expect(await AppSettings.getLastActivities(), isEmpty);
  });

  testWidgets('recall button adds the last parks, without duplicates', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.saveLastActivities([usA, usB]);

    // usA is already selected on this contact; recall should only add usB.
    await _openDialog(tester, [usA]);
    final recall = find.byTooltip('Recall last: US-1234, US-10456');
    expect(recall, findsOneWidget);

    await tester.tap(recall);
    await tester.pumpAndSettle();
    expect(find.text('POTA: US-1234'), findsOneWidget);
    expect(find.text('POTA: US-10456'), findsOneWidget);

    // Tapping again changes nothing.
    await tester.tap(recall);
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsNWidgets(2));
  });

  testWidgets('recall button is disabled when nothing has been logged with a park', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _openDialog(tester, []);
    final button = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.history));
    expect(button.onPressed, isNull);
    expect(find.byTooltip('No recent parks'), findsOneWidget);
  });

  testWidgets('recalled parks are returned by Save Selection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.saveLastActivities([usA, usB]);
    List<ActivityRef>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showDialog<List<ActivityRef>>(
              context: context,
              builder: (_) => const ActivitySelectionDialog(selected: []),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Selection'));
    await tester.pumpAndSettle();
    expect(result?.map((r) => r.reference), ['US-1234', 'US-10456']);
  });
}
