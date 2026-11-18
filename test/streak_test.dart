import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_portable/services/streak_service.dart';
import 'package:wavelog_portable/services/wavelog_endpoint.dart';
import 'package:wavelog_portable/services/streak_reminder.dart';
import 'package:wavelog_portable/widgets/streak_banner.dart';

final now = DateTime.utc(2026, 11, 18, 20, 30); // 20:30Z, 3.5 h before the day ends
DateTime d(int month, int day) => DateTime.utc(2026, month, day);

/// A logbook with QSOs on [days] (2 per day unless [counts] says otherwise);
/// records which days were asked about.
class FakeLog {
  final Set<String> days;
  final Map<String, int> counts = {};
  final List<String> asked = [];
  bool offline = false;
  FakeLog(Iterable<DateTime> days) : days = days.map(StreakService.day).toSet();

  Future<int?> check(DateTime day) async {
    final d = StreakService.day(day);
    asked.add(d);
    if (offline) return null;
    return days.contains(d) ? (counts[d] ?? 2) : 0;
  }
}

Iterable<DateTime> run(DateTime from, DateTime to) sync* {
  for (var x = from; !x.isAfter(to); x = x.add(const Duration(days: 1))) {
    yield x;
  }
}

void main() {
  reminderAndBannerTests();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('QSO today: streak counts today', () async {
    final log = FakeLog(run(d(11, 6), d(11, 18)));
    log.counts['2026-11-18'] = 12;
    final s = await StreakService.compute(log.check, now: now);
    expect(s.days, 13);
    expect(s.qsoToday, isTrue);
    expect(s.todayCount, 12);
    expect(s.atRisk, isFalse);
  });

  test('no QSO yet today: streak through yesterday is at risk, with time left', () async {
    final log = FakeLog(run(d(11, 10), d(11, 17)));
    final s = await StreakService.compute(log.check, now: now);
    expect(s.days, 8);
    expect(s.qsoToday, isFalse);
    expect(s.todayCount, 0);
    expect(s.atRisk, isTrue);
    expect(s.timeLeft, const Duration(hours: 3, minutes: 30));
  });

  test('gap yesterday: no streak, nothing at risk', () async {
    final log = FakeLog(run(d(11, 1), d(11, 16)));
    final s = await StreakService.compute(log.check, now: now);
    expect(s.days, 0);
    expect(s.atRisk, isFalse);
  });

  test('a long streak is only checked once; later refreshes reuse the cache', () async {
    final log = FakeLog(run(d(1, 1), d(11, 18)));
    final first = await StreakService.compute(log.check, now: now);
    expect(first.days, 322);
    expect(log.asked.length, greaterThan(300));

    log.asked.clear();
    final again = await StreakService.compute(log.check, now: now);
    expect(again.days, 322);
    // Today is always asked (for its count), plus at most one batch.
    expect(log.asked.length, lessThanOrEqualTo(StreakService.batchSize + 1));

    // Next day, after logging: only the new days need checking.
    log.days.add(StreakService.day(d(11, 19)));
    log.asked.clear();
    final tomorrow = await StreakService.compute(log.check, now: DateTime.utc(2026, 11, 19, 12));
    expect(tomorrow.days, 323);
    expect(log.asked.length, lessThanOrEqualTo(StreakService.batchSize + 2));
  });

  test('a contact logged on this phone today counts, even offline', () async {
    final log = FakeLog(run(d(11, 1), d(11, 17)));
    await StreakService.compute(log.check, now: now); // caches Nov 1-17
    await StreakService.recordLocalQso(DateTime.utc(2026, 11, 18, 19, 0));
    await StreakService.recordLocalQso(DateTime.utc(2026, 11, 18, 19, 5));
    log.offline = true;
    final s = await StreakService.compute(log.check, now: now);
    expect(s.qsoToday, isTrue);
    expect(s.days, 18);
    expect(s.todayCount, 2); // the two logged on this phone
  });

  test('count today: Wavelog\'s count, or the phone\'s when more are waiting to upload', () async {
    final log = FakeLog(run(d(11, 1), d(11, 18)))..counts['2026-11-18'] = 5;
    expect((await StreakService.compute(log.check, now: now)).todayCount, 5);
    for (var i = 0; i < 7; i++) {
      await StreakService.recordLocalQso(DateTime.utc(2026, 11, 18, 10, i));
    }
    expect((await StreakService.compute(log.check, now: now)).todayCount, 7);
  });

  test('phone count resets on a new UTC day', () async {
    await StreakService.recordLocalQso(DateTime.utc(2026, 11, 17, 23, 50));
    final log = FakeLog(run(d(11, 1), d(11, 17)))..offline = true;
    final s = await StreakService.compute(log.check, now: now);
    expect(s.todayCount, isNull);
    expect(s.qsoToday, isFalse);
  });

  test('offline with no cache: no streak shown rather than a wrong one', () async {
    final log = FakeLog(run(d(11, 1), d(11, 17)))..offline = true;
    final s = await StreakService.compute(log.check, now: now);
    expect(s.days, 0);
    expect(s.qsoToday, isFalse);
  });

  group('Wavelog day check', () {
    test('asks for one UTC day and reads meta.total', () async {
      final sent = <http.Request>[];
      final ep = WavelogEndpoint('https://log.example.com', 'wl2_abcdef0123456789');
      final answer = await http.runWithClient(
        () => StreakService.wavelogDayChecker(ep)(d(11, 18)),
        () => MockClient((r) async {
          sent.add(r);
          return http.Response(jsonEncode({'data': [], 'meta': {'total': 3}}), 200);
        }),
      );
      expect(answer, 3);
      expect(sent.single.url.path, '/index.php/api/v2/qso');
      expect(sent.single.url.queryParameters,
          {'qso_since': '2026-11-18', 'qso_until': '2026-11-18', 'per_page': '1'});
    });

    test('errors are "unknown", not "no QSO"', () async {
      final ep = WavelogEndpoint('https://log.example.com', 'wl2_abcdef0123456789');
      final answer = await http.runWithClient(
        () => StreakService.wavelogDayChecker(ep)(d(11, 18)),
        () => MockClient((_) async => http.Response('{"error":{"message":"nope"}}', 500)),
      );
      expect(answer, isNull);
    });
  });

  test('switched off or v1 key: no streak', () async {
    SharedPreferences.setMockInitialValues({
      'wavelog_url': 'https://log.example.com', 'wavelog_key': 'wl2_abcdef0123456789', 'streak_enabled': false,
    });
    expect(await StreakService.current(now: now, offline: true), isNull);
    SharedPreferences.setMockInitialValues({
      'wavelog_url': 'https://log.example.com', 'wavelog_key': 'cl1234567890abc',
    });
    expect(await StreakService.current(now: now, offline: true), isNull);
  });
}

void reminderAndBannerTests() {
  group('StreakReminder.nextCheck', () {
    test('later today when before 21:45Z, else tomorrow', () {
      expect(StreakReminder.nextCheck(DateTime.utc(2026, 11, 18, 9)), DateTime.utc(2026, 11, 18, 21, 45));
      expect(StreakReminder.nextCheck(DateTime.utc(2026, 11, 18, 21, 44)), DateTime.utc(2026, 11, 18, 21, 45));
      expect(StreakReminder.nextCheck(DateTime.utc(2026, 11, 18, 21, 45)), DateTime.utc(2026, 11, 19, 21, 45));
      expect(StreakReminder.nextCheck(DateTime.utc(2026, 11, 18, 23, 59)), DateTime.utc(2026, 11, 19, 21, 45));
      expect(StreakReminder.nextCheck(DateTime.utc(2026, 12, 31, 23)), DateTime.utc(2027, 1, 1, 21, 45));
    });
    test('notification text', () {
      expect(StreakReminder.title(12), 'Your 12-day streak ends at 00:00 UTC');
      expect(StreakReminder.title(1), 'Your 1-day streak ends at 00:00 UTC');
      expect(StreakReminder.body(const Duration(hours: 2, minutes: 15)),
          'No contacts logged today (UTC). 2h 15m left to make one and keep it going.');
      expect(StreakReminder.body(const Duration(minutes: 40)),
          'No contacts logged today (UTC). 40m left to make one and keep it going.');
    });
  });

  group('StreakBanner', () {
    Future<void> pump(WidgetTester tester, StreakStatus s) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: StreakBanner(status: s))));

    testWidgets('logged today, with the count', (tester) async {
      await pump(tester, StreakStatus(days: 12, qsoToday: true, nowUtc: now, todayCount: 7));
      expect(find.text('12-day streak · 7 QSOs today'), findsOneWidget);
      await pump(tester, StreakStatus(days: 1, qsoToday: true, nowUtc: now, todayCount: 1));
      expect(find.text('1-day streak · 1 QSO today'), findsOneWidget);
    });
    testWidgets('logged today, count unknown (offline)', (tester) async {
      await pump(tester, StreakStatus(days: 12, qsoToday: true, nowUtc: now));
      expect(find.text('12-day streak · logged today'), findsOneWidget);
    });
    testWidgets('at risk shows the time left', (tester) async {
      await pump(tester, StreakStatus(days: 12, qsoToday: false, nowUtc: DateTime.utc(2026, 11, 18, 22, 50)));
      expect(find.text('No contacts today · 12-day streak ends in 1h 10m'), findsOneWidget);
    });
    testWidgets('no streak, nothing yet today', (tester) async {
      await pump(tester, StreakStatus(days: 0, qsoToday: false, nowUtc: now));
      expect(find.text('No contacts today (UTC) yet'), findsOneWidget);
    });
  });
}
