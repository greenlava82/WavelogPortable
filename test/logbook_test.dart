import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_portable/locator.dart';
import 'package:wavelog_portable/main.dart';
import 'package:wavelog_portable/models/log_entry.dart';
import 'package:wavelog_portable/services/database_service.dart';
import 'package:wavelog_portable/services/logbook_service.dart';
import 'package:wavelog_portable/services/session_service.dart';

const v2Key = 'wl2_abcdef0123456789';

/// Two contacts logged on the phone, newest first (as the DB query returns).
class FakeDb extends DatabaseService {
  FakeDb() : super.create();
  int? requestedLimit;

  @override
  Future<List<Map<String, dynamic>>> getRecentSessionQsos(int limit) async {
    requestedLimit = limit;
    return [
      _row('K1ABC', '40m', 'CW', DateTime.utc(2026, 11, 18, 14, 5)),
      _row('W1AW', '20m', 'FreeDV', DateTime.utc(2026, 11, 17, 9, 30)),
    ];
  }

  @override
  Future<Map<String, dynamic>?> getActiveSession() async => null;
  @override
  Future<List<Map<String, dynamic>>> getUnuploadedSessionQsos() async => [];

  static Map<String, dynamic> _row(String call, String band, String mode, DateTime t) => {
        'id': 1, 'session_id': 0, 'callsign': call, 'band': band, 'mode': mode,
        'freq': 14.0, 'timestamp': t.millisecondsSinceEpoch, 'rst_sent': '59',
        'rst_rcvd': '59', 'is_uploaded': 1,
      };
}

void main() {
  group('LogEntry', () {
    test('from Wavelog v2 JSON, submode preferred over mode', () {
      final e = LogEntry.fromWavelogV2({
        'call': 'IS0KNG', 'band': '10m', 'mode': 'DIGITALVOICE', 'submode': 'FREEDV',
        'qso_date': '2026-11-18 20:52:09',
      });
      expect(e.callsign, 'IS0KNG');
      expect(e.band, '10m');
      expect(e.mode, 'FREEDV');
      expect(e.timeUtc, DateTime.utc(2026, 11, 18, 20, 52, 9));
      expect(e.timeLabel, '2026-11-18 20:52Z');
    });

    test('plain mode when there is no submode; missing time shows a dash', () {
      final e = LogEntry.fromWavelogV2({'call': 'W1AW', 'band': '20m', 'mode': 'SSB', 'submode': null});
      expect(e.mode, 'SSB');
      expect(e.timeLabel, '-');
    });
  });

  group('LogbookService.recent', () {
    late FakeDb db;
    late List<http.Request> sent;
    late http.Response Function() reply;

    setUp(() {
      db = FakeDb();
      sent = [];
      reply = () => http.Response('{}', 200);
    });

    void prefs(String key) => SharedPreferences.setMockInitialValues({
          'wavelog_url': 'https://log.example.com',
          'wavelog_key': key,
        });

    Future<LogbookResult> recent({bool offline = false}) => http.runWithClient(
          () => LogbookService.recent(25, offline: offline, db: db),
          () => MockClient((r) async {
            sent.add(r);
            return reply();
          }),
        );

    test('v2 key: newest QSOs from Wavelog', () async {
      prefs(v2Key);
      reply = () => http.Response(
          '{"data":[{"call":"IS0KNG","band":"10m","mode":"SSB","submode":null,"qso_date":"2026-11-18 20:52:09"}],"meta":{}}',
          200);
      final result = await recent();
      expect(sent.single.url.toString(), 'https://log.example.com/index.php/api/v2/qso?limit=25');
      expect(sent.single.headers['Authorization'], 'Bearer $v2Key');
      expect(result.source, LogbookSource.wavelog);
      expect(result.note, isNull);
      expect(result.entries.single.callsign, 'IS0KNG');
      expect(db.requestedLimit, isNull);
    });

    test('v2 key without qso:read: falls back to the phone and says why', () async {
      prefs(v2Key);
      reply = () => http.Response(
          '{"error":{"code":"insufficient_scope","message":"Token is missing the required scope: qso:read"}}', 403);
      final result = await recent();
      expect(result.source, LogbookSource.phone);
      expect(result.note,
          'Token is missing the required scope: qso:read. Showing contacts logged on this phone');
      expect(result.entries.map((e) => e.callsign), ['K1ABC', 'W1AW']);
      expect(db.requestedLimit, 25);
    });

    test('v1 key: no network call, phone contacts with an explanation', () async {
      prefs('cl1234567890abc');
      final result = await recent();
      expect(sent, isEmpty);
      expect(result.source, LogbookSource.phone);
      expect(result.note, startsWith('Viewing the Wavelog log needs an API v2 (wl2_) key'));
    });

    test('offline mode: phone contacts, no network call', () async {
      prefs(v2Key);
      final result = await recent(offline: true);
      expect(sent, isEmpty);
      expect(result.source, LogbookSource.phone);
      expect(result.note, 'Offline mode: showing contacts logged on this phone');
      expect(result.entries.first.timeLabel, '2026-11-18 14:05Z');
    });
  });

  testWidgets('Logbook icon opens the viewer with the last contacts', (tester) async {
    SharedPreferences.setMockInitialValues({
      'my_callsign': 'K1GLV', 'my_grid': 'FN42',
      'wavelog_url': 'https://log.example.com', 'wavelog_key': 'cl1234567890abc',
      'offline_mode': 'false',
    });
    await locator.reset();
    locator.registerSingleton<DatabaseService>(FakeDb());
    locator.registerSingleton<SessionService>(SessionService.create(databaseService: locator<DatabaseService>()));

    await tester.pumpWidget(const WavelogPortable());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Logbook'));
    await tester.pumpAndSettle();

    expect(find.text('Last 25 Contacts'), findsOneWidget);
    expect(find.text('K1ABC'), findsOneWidget);
    expect(find.text('W1AW'), findsOneWidget);
    expect(find.text('40m'), findsOneWidget);
    expect(find.text('FreeDV'), findsOneWidget);
    expect(find.text('2026-11-18 14:05Z'), findsOneWidget);
    expect(find.textContaining('needs an API v2 (wl2_) key'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
