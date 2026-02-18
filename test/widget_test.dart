import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
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
}
