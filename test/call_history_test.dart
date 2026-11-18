import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_portable/models/call_history.dart';
import 'package:wavelog_portable/models/log_entry.dart';
import 'package:wavelog_portable/services/logbook_service.dart';
import 'package:wavelog_portable/services/wavelog_service.dart';
import 'package:wavelog_portable/widgets/call_history_card.dart';
import 'package:wavelog_portable/locator.dart';
import 'package:wavelog_portable/screens/details_screen.dart';
import 'package:wavelog_portable/services/database_service.dart';
import 'package:wavelog_portable/services/session_service.dart';

const v1Key = 'cl1234567890abc';
const v2Key = 'wl2_abcdef0123456789';
const url = 'https://log.example.com';

LogEntry entry(String band, String mode, {String? submode, String date = '2026-10-02 20:15:00'}) =>
    LogEntry.fromWavelogV2({'call': 'W1AW', 'band': band, 'mode': mode, 'submode': submode, 'qso_date': date});

void main() {
  detailsScreenTests();

  group('LogEntry.isOn (band and mode match)', () {
    test('FreeDV matches SUBMODE=FREEDV', () {
      expect(entry('20m', 'DIGITALVOICE', submode: 'FREEDV').isOn('20m', 'FreeDV'), isTrue);
    });
    test('SSB matches a contact stored as SSB/USB', () {
      final e = entry('20m', 'SSB', submode: 'USB');
      expect(e.mode, 'USB');
      expect(e.isOn('20m', 'SSB'), isTrue);
    });
    test('different band or mode does not match; band compare ignores case', () {
      expect(entry('20M', 'CW').isOn('20m', 'CW'), isTrue);
      expect(entry('40m', 'CW').isOn('20m', 'CW'), isFalse);
      expect(entry('20m', 'FT8').isOn('20m', 'CW'), isFalse);
    });
  });

  group('WavelogService.fetchCallHistory', () {
    late List<http.Request> sent;
    late http.Response Function() reply;
    setUp(() {
      sent = [];
      reply = () => http.Response('{}', 200);
    });
    Future<(CallHistory?, String?)> fetch(String key, String call) => http.runWithClient(
          () => WavelogService.fetchCallHistory(url, key, call, 5),
          () => MockClient((r) async {
            sent.add(r);
            return reply();
          }),
        );

    test('v2: filters by callsign, newest first, with the total', () async {
      reply = () => http.Response(
          '{"data":[{"call":"W1AW","band":"20m","mode":"FT8","submode":null,"qso_date":"2026-10-02 20:15:00"},'
          '{"call":"W1AW","band":"40m","mode":"SSB","submode":"LSB","qso_date":"2025-06-14 01:02:00"}],'
          '"meta":{"page":1,"per_page":5,"count":2,"total":7}}',
          200);
      final (history, error) = await fetch(v2Key, ' w1aw ');
      final r = sent.single;
      expect(r.method, 'GET');
      expect(r.url.path, '/index.php/api/v2/qso');
      expect(r.url.queryParameters, {'callsign': 'W1AW', 'per_page': '5'});
      expect(r.headers['Authorization'], 'Bearer $v2Key');
      expect(error, isNull);
      expect(history!.total, 7);
      expect(history.recent.map((e) => '${e.band} ${e.mode}'), ['20m FT8', '40m LSB']);
    });

    test('never worked: total 0', () async {
      reply = () => http.Response('{"data":[],"meta":{"total":0}}', 200);
      final (history, _) = await fetch(v2Key, 'K1ABC');
      expect(history!.total, 0);
      expect(history.recent, isEmpty);
    });

    test('missing qso:read scope: no history, reason returned', () async {
      reply = () => http.Response(
          '{"error":{"code":"insufficient_scope","message":"Token is missing the required scope: qso:read"}}', 403);
      final (history, error) = await fetch(v2Key, 'W1AW');
      expect(history, isNull);
      expect(error, 'Token is missing the required scope: qso:read');
    });

    test('v1 key: no request', () async {
      final (history, error) = await fetch(v1Key, 'W1AW');
      expect(sent, isEmpty);
      expect(history, isNull);
      expect(error, contains('API v2'));
    });
  });

  test('LogbookService.callHistory makes no request in offline mode', () async {
    SharedPreferences.setMockInitialValues({'wavelog_url': url, 'wavelog_key': v2Key});
    var calls = 0;
    final history = await http.runWithClient(
      () => LogbookService.callHistory('W1AW', offline: true),
      () => MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    expect(history, isNull);
    expect(calls, 0);
  });

  testWidgets('history card: count, rows and "+ more"', (tester) async {
    final history = CallHistory(7, [
      entry('20m', 'FT8', date: '2026-10-02 20:15:00'),
      entry('40m', 'SSB', submode: 'LSB', date: '2025-06-14 01:02:00'),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CallHistoryCard(history: history, band: '20m', mode: 'FT8')),
    ));
    expect(find.text('Worked 7× before'), findsOneWidget);
    expect(find.text('2026-10-02 20:15Z'), findsOneWidget);
    expect(find.text('LSB'), findsOneWidget);
    expect(find.text('+ 5 more'), findsOneWidget);

    // Same band and mode is highlighted; another band is not.
    final ft8 = tester.widget<Text>(find.text('FT8'));
    final lsb = tester.widget<Text>(find.text('LSB'));
    expect(ft8.style!.fontWeight, FontWeight.bold);
    expect(lsb.style!.fontWeight, FontWeight.normal);
  });

  testWidgets('history card: a single contact', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CallHistoryCard(history: CallHistory(1, [entry('20m', 'CW')]), band: '40m', mode: 'CW'),
      ),
    ));
    expect(find.text('Worked once before'), findsOneWidget);
    expect(find.textContaining('more'), findsNothing);
  });
}

class _FakeDb extends DatabaseService {
  _FakeDb() : super.create();
  @override
  Future<Map<String, dynamic>?> getActiveSession() async => null;
  @override
  Future<List<Map<String, dynamic>>> getUnuploadedSessionQsos() async => [];
  @override
  Future<Map<String, dynamic>?> getCachedCallsign(String callsign) async => null;
  @override
  Future<void> cacheCallsign(Map<String, dynamic> profile) async {}
}

void detailsScreenTests() {
  testWidgets('Log Contact: WORKED badge shows the count and opens the history; no inline card',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'my_callsign': 'K1GLV', 'my_grid': 'FN42', 'wavelog_url': url, 'wavelog_key': v2Key,
      'offline_mode': 'false', 'last_band': '20m', 'last_mode': 'SSB',
    });
    await locator.reset();
    locator.registerSingleton<DatabaseService>(_FakeDb());
    locator.registerSingleton<SessionService>(SessionService.create(databaseService: locator<DatabaseService>()));

    final wavelog = MockClient((r) async {
      if (r.url.path.endsWith('/api/v2/qso')) {
        return http.Response(
            '{"data":[{"call":"W1AW","band":"20m","mode":"SSB","submode":"USB","qso_date":"2026-10-02 20:15:00"},'
            '{"call":"W1AW","band":"40m","mode":"CW","submode":null,"qso_date":"2025-06-14 01:02:00"}],'
            '"meta":{"total":2}}',
            200);
      }
      if (r.url.path.endsWith('/api/v2/lookup')) {
        return http.Response(
            '{"data":{"call_worked":true,"call_worked_band":true,"call_worked_band_mode":true}}', 200);
      }
      return http.Response('', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: QsoDetailsScreen(callsign: 'W1AW')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }, () => wavelog);

    expect(find.text('WORKED 2×'), findsOneWidget);
    expect(find.byType(CallHistoryCard), findsNothing); // nothing added to the page itself

    await tester.tap(find.text('WORKED 2×'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CallHistoryCard), findsOneWidget);
    expect(find.text('Worked 2× before'), findsOneWidget);
    expect(find.text('2026-10-02 20:15Z'), findsOneWidget);
    expect(find.text('Session log'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CallHistoryCard), findsNothing);
    await tester.pumpWidget(const SizedBox()); // stop the clock timer
  });
}
