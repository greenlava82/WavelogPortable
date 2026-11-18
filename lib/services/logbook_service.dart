import '../models/log_entry.dart';
import '../models/session_qso.dart';
import 'database_service.dart';
import 'settings_service.dart';
import 'wavelog_service.dart';

enum LogbookSource { wavelog, phone }

/// What the logbook viewer shows, where it came from, and why (when it had
/// to fall back to the contacts logged on this phone).
class LogbookResult {
  final List<LogEntry> entries;
  final LogbookSource source;
  final String? note;

  const LogbookResult(this.entries, this.source, [this.note]);
}

class LogbookService {
  /// The newest [limit] contacts: from Wavelog when the app is online with an
  /// API v2 key, otherwise from the contacts logged on this phone.
  static Future<LogbookResult> recent(
    int limit, {
    required bool offline,
    DatabaseService? db,
  }) async {
    String? note;
    if (offline) {
      note = 'Offline mode: showing contacts logged on this phone';
    } else {
      final url = await AppSettings.getString(AppSettings.keyWavelogUrl);
      final key = await AppSettings.getString(AppSettings.keyWavelogKey);
      final (entries, error) = await WavelogService.fetchRecentQsos(url, key, limit);
      if (entries != null) return LogbookResult(entries, LogbookSource.wavelog);
      note = '$error. Showing contacts logged on this phone';
    }

    final rows = await (db ?? DatabaseService()).getRecentSessionQsos(limit);
    final entries = rows.map((r) => LogEntry.fromSessionQso(SessionQso.fromMap(r))).toList();
    return LogbookResult(entries, LogbookSource.phone, note);
  }
}
