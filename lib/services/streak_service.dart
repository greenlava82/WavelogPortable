import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_service.dart';
import 'wavelog_endpoint.dart';

/// The daily-QSO streak, counted the way Wavelog's dashboard does: the
/// number of consecutive UTC days with at least one QSO, ending today, or
/// ending yesterday when there is no QSO yet today (the streak can still be
/// saved until 00:00Z).
class StreakStatus {
  /// Consecutive days, including today when [qsoToday].
  final int days;

  /// At least one QSO on today's UTC date.
  final bool qsoToday;

  /// QSOs on today's UTC date, or null when unknown (e.g. offline and only
  /// the cached streak says today is covered).
  final int? todayCount;

  /// When this was worked out.
  final DateTime nowUtc;

  const StreakStatus({required this.days, required this.qsoToday, required this.nowUtc, this.todayCount});

  StreakStatus at(DateTime nowUtc) =>
      StreakStatus(days: days, qsoToday: qsoToday, nowUtc: nowUtc, todayCount: todayCount);

  /// A streak that ends tonight at 00:00Z unless a QSO is logged.
  bool get atRisk => !qsoToday && days > 0;

  /// Time until 00:00Z, when today's chance to keep the streak ends.
  Duration get timeLeft {
    final midnight = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day + 1);
    return midnight.difference(nowUtc);
  }
}

/// How many QSOs are on this UTC date, or null when that can't be found out
/// (no network, error).
typedef DayChecker = Future<int?> Function(DateTime dayUtc);

class StreakService {
  static const String keyCache = 'streak_cache';
  static const String keyLastLocalQsoDay = 'last_local_qso_day';
  static const String keyLocalQsoCount = 'local_qso_count'; // "YYYY-MM-DD:N"

  /// How many days are checked with Wavelog at once.
  static const int batchSize = 7;

  /// Never walk back further than this.
  static const int maxDays = 3660;

  static String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _date(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Remember that a QSO was logged on this phone today (UTC), so the streak
  /// shows as safe right away, even offline.
  static Future<void> recordLocalQso(DateTime timeOn) async {
    final prefs = await SharedPreferences.getInstance();
    final d = day(timeOn.toUtc());
    await prefs.setString(keyLastLocalQsoDay, d);
    await prefs.setString(keyLocalQsoCount, '$d:${_localCount(prefs, d) + 1}');
  }

  /// Contacts logged on this phone on UTC date [d].
  static int _localCount(SharedPreferences prefs, String d) {
    final parts = (prefs.getString(keyLocalQsoCount) ?? '').split(':');
    return parts.length == 2 && parts[0] == d ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  /// The streak from Wavelog, or null when it isn't available (feature
  /// switched off, no v2 key). Without network it falls back to the last
  /// known streak plus contacts logged on this phone.
  static Future<StreakStatus?> current({DateTime? now, bool offline = false}) async {
    if (!await AppSettings.getStreakEnabled()) return null;
    final url = await AppSettings.getString(AppSettings.keyWavelogUrl);
    final key = await AppSettings.getString(AppSettings.keyWavelogKey);
    final ep = WavelogEndpoint(url, key);
    if (!ep.isConfigured || !ep.isV2) return null;
    final checker = offline ? (DateTime _) async => null : wavelogDayChecker(ep);
    return compute(checker, now: now);
  }

  /// Asks Wavelog's v2 API for the number of QSOs on one UTC date.
  static DayChecker wavelogDayChecker(WavelogEndpoint ep) => (DateTime d) async {
        try {
          final response = await http
              .get(
                ep.uri('qso', {'qso_since': day(d), 'qso_until': day(d), 'per_page': '1'}),
                headers: ep.headers,
              )
              .timeout(const Duration(seconds: 15));
          if (response.statusCode != 200) return null;
          final total = jsonDecode(response.body)['meta']?['total'];
          return total is int ? total : null;
        } catch (_) {
          return null;
        }
      };

  /// Works out the streak with [hasQso], using and updating the cached run of
  /// days already known to have QSOs so a long streak isn't re-checked every
  /// time. Exposed for tests.
  static Future<StreakStatus> compute(DayChecker hasQso, {DateTime? now}) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final today = _date(nowUtc);
    final yesterday = today.subtract(const Duration(days: 1));
    final prefs = await SharedPreferences.getInstance();

    // Cached run: every day from start to end (inclusive) has a QSO.
    DateTime? cacheStart, cacheEnd;
    try {
      final c = jsonDecode(prefs.getString(keyCache) ?? '');
      cacheStart = DateTime.parse('${c['start']}T00:00:00Z');
      cacheEnd = DateTime.parse('${c['end']}T00:00:00Z');
    } catch (_) {}

    bool? known(DateTime d) {
      if (cacheStart != null && !d.isBefore(cacheStart) && !d.isAfter(cacheEnd!)) return true;
      if (d == today && prefs.getString(keyLastLocalQsoDay) == day(today)) return true;
      return null;
    }

    // Each day is asked about at most once per run.
    final asked = <DateTime, Future<int?>>{};
    Future<int?> count(DateTime d) => asked.putIfAbsent(d, () => hasQso(d));
    Future<bool?> check(DateTime d) async {
      final k = known(d);
      if (k != null) return k;
      final n = await count(d);
      return n == null ? null : n > 0;
    }

    // Today is always asked (for the count), and combined with the contacts
    // logged on this phone, which may not have reached Wavelog yet.
    final wavelogToday = await count(today);
    final localToday = _localCount(prefs, day(today));
    final int? todayCount = wavelogToday == null
        ? (localToday > 0 ? localToday : null)
        : (wavelogToday > localToday ? wavelogToday : localToday);
    final qsoToday = (todayCount ?? 0) > 0 || known(today) == true;

    // Walk back from the newest day that counts, in batches.
    var cursor = qsoToday ? today : yesterday;
    DateTime? runStart;
    var reachedGap = false;
    var unknown = false;
    while (!reachedGap && !unknown && today.difference(cursor).inDays < maxDays) {
      // Jump over the cached run.
      if (cacheStart != null && known(cursor) == true && cursor != today) {
        runStart = cacheStart;
        cursor = cacheStart.subtract(const Duration(days: 1));
        continue;
      }
      final batch = [for (var i = 0; i < batchSize; i++) cursor.subtract(Duration(days: i))];
      final answers = await Future.wait(batch.map(check));
      for (var i = 0; i < batch.length; i++) {
        if (answers[i] == true) {
          runStart = batch[i];
        } else {
          reachedGap = answers[i] == false;
          unknown = answers[i] == null;
          break;
        }
      }
      cursor = batch.last.subtract(const Duration(days: 1));
    }

    final end = qsoToday ? today : yesterday;
    final days = runStart == null ? 0 : end.difference(runStart).inDays + 1;

    // Only cache a run whose start is confirmed (a real gap before it), so
    // an unreachable server doesn't shorten the streak for next time.
    if (runStart != null && !unknown) {
      await prefs.setString(keyCache, jsonEncode({'start': day(runStart), 'end': day(end)}));
    }

    return StreakStatus(
      days: days,
      qsoToday: qsoToday,
      nowUtc: nowUtc,
      todayCount: todayCount,
    );
  }
}
