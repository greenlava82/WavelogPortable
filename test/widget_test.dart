import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_portable/main.dart';
import 'package:wavelog_portable/services/database_service.dart';
import 'package:wavelog_portable/services/session_service.dart';
import 'package:wavelog_portable/locator.dart';

// Fake DatabaseService to bypass sqflite
class FakeDatabaseService extends DatabaseService {
  FakeDatabaseService() : super.create();

  @override
  Future<Map<String, dynamic>?> getActiveSession() async => null;

  @override
  Future<List<Map<String, dynamic>>> getSessions() async => [];
  
  @override
  Future<int> getOfflineQueueSize() async => 0;

  @override
  Future<List<Map<String, dynamic>>> getUnuploadedSessionQsos() async => [];
  
  // Add other overrides if needed by initial load
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'my_callsign': 'TEST',
      'my_grid': 'FN00',
      'wavelog_url': 'http://test.com',
      'wavelog_key': 'test_key',
      'offline_mode': 'false'
    });
    
    await locator.reset();
    
    // Register Fakes
    locator.registerSingleton<DatabaseService>(FakeDatabaseService());
    locator.registerSingleton<SessionService>(SessionService.create(databaseService: locator<DatabaseService>()));
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WavelogPortable());
    
    // Allow async init to complete if any
    await tester.pumpAndSettle();

    // Verify that the app title is displayed
    expect(find.text('Wavelog Portable'), findsOneWidget);
    
    // Initial status should be online (mocked prefs default) or offline depending on logic
    // We just verify basic rendering
  });

  testWidgets('Sync Queue from drawer does not leave spinner stuck', (WidgetTester tester) async {
    // Wavelog answers slowly, so the drawer has finished closing before the response arrives.
    final slowWavelog = MockClient((request) async {
      await Future.delayed(const Duration(seconds: 1));
      return http.Response(
        jsonEncode([{'station_id': 1, 'station_profile_name': 'Home'}]),
        200,
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const WavelogPortable());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync Queue'));

      // Run frames so the drawer finishes closing and leaves the tree,
      // then let the slow station fetch finish.
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Sync Pending QSOs'), findsOneWidget);
    }, () => slowWavelog);
  });
}
