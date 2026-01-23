import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../models/session_qso.dart';
import '../models/rst_report.dart';
import '../models/lookup_result.dart';
import 'database_service.dart';
import 'wavelog_service.dart';
import 'settings_service.dart';

class SessionService extends ChangeNotifier {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Session? _currentSession;
  bool _isOfflineMode = false;
  
  Session? get currentSession => _currentSession;
  bool get isOfflineMode => _isOfflineMode;

  Future<void> init() async {
    final db = DatabaseService();
    
    // Load Offline Mode
    String offline = await AppSettings.getString(AppSettings.keyOfflineMode, defaultValue: 'false');
    _isOfflineMode = offline == 'true';
    
    // Load Active Session
    final sessionMap = await db.getActiveSession();
    if (sessionMap != null) {
      _currentSession = Session.fromMap(sessionMap);
      print("RESTORED SESSION: ${_currentSession!.name}");
    }
    notifyListeners();
  }

  Future<void> setOfflineMode(bool isOffline) async {
    _isOfflineMode = isOffline;
    await AppSettings.saveString(AppSettings.keyOfflineMode, isOffline.toString());
    notifyListeners();
    
    // If going online, we could optionally prompt to sync, but the UI should handle that trigger.
  }

  Future<void> startSession(String name) async {
    if (_currentSession != null) {
      await stopSession();
    }
    
    final newSession = Session(
      name: name,
      startTime: DateTime.now(),
      isActive: true,
    );
    
    final db = DatabaseService();
    int id = await db.createSession(newSession.toMap());
    
    // Reload to get ID
    _currentSession = Session(
      id: id,
      name: name,
      startTime: newSession.startTime,
      isActive: true,
    );
    
    notifyListeners();
  }

  Future<void> stopSession() async {
    if (_currentSession != null && _currentSession!.id != null) {
      final db = DatabaseService();
      await db.closeSession(_currentSession!.id!, DateTime.now().millisecondsSinceEpoch);
      _currentSession = null;
      notifyListeners();
    }
  }

  /// Main logging function. Returns true if saved locally. 
  /// The UI should observe 'isUploaded' status if it cares.
  Future<bool> logQso({
    required String callsign,
    required String band,
    required String mode,
    required double freq,
    required DateTime timeOn,
    required RstReport rstSent,
    required RstReport rstRcvd,
    String? grid,
    String? name,
    String? qth,
    String? state,
    String? country,
    String? potaList,
    String? sotaRef,
  }) async {
    
    // 1. Create SessionQso object
    // If no active session, we can still save it with null session_id (if allowed) or handle ad-hoc.
    // However, the DB schema has session_id as integer. Let's assume nullable if not enforced.
    // The previous SQL was: session_id INTEGER ... FOREIGN KEY.
    // In SQLite, FKs can be null.
    
    final qso = SessionQso(
      sessionId: _currentSession?.id ?? 0, // 0 implies no session or ad-hoc if 0 isn't a valid ID (IDs start at 1).
      callsign: callsign,
      band: band,
      mode: mode,
      freq: freq,
      timestamp: timeOn,
      rstSent: rstSent.formatted(mode == 'CW'),
      rstRcvd: rstRcvd.formatted(mode == 'CW'),
      potaRef: potaList,
      sotaRef: sotaRef,
      grid: grid,
      name: name,
      qth: qth,
      state: state,
      country: country,
      isUploaded: false, // Default to false
    );

    final db = DatabaseService();
    int qsoId = await db.insertSessionQso(qso.toMap());
    print("LOGGED QSO Locally: ID $qsoId");

    // 2. Upload Logic
    if (!_isOfflineMode) {
      bool success = await WavelogService.postQso(
        callsign: callsign,
        band: band,
        mode: mode,
        freq: freq,
        timeOn: timeOn,
        rstSent: rstSent,
        rstRcvd: rstRcvd,
        grid: grid,
        name: name,
        qth: qth,
        state: state,
        country: country,
        potaList: potaList,
        sotaRef: sotaRef,
      );

      if (success) {
        await db.markSessionQsoUploaded(qsoId);
        print("UPLOADED QSO: ID $qsoId");
      }
    }

    notifyListeners();
    return true; 
  }

  /// Checks for duplicates in the CURRENT session + Online if applicable.
  Future<LookupResult> checkDupe(String callsign, String band, String mode) async {
    final db = DatabaseService();
    LookupResult result = LookupResult();

    // 1. Check Local Session (if active)
    if (_currentSession != null && _currentSession!.id != null) {
      bool localDupe = await db.checkSessionDupe(_currentSession!.id!, callsign, band, mode);
      if (localDupe) {
        // We only know it's a dupe on band/mode match from the specialized SQL query
        // The SQL was: WHERE session_id = ? AND callsign = ? AND band = ? AND mode = ?
        // So if true, it's a Band+Mode match.
        // We could expand the SQL to check generic callsign match too, but for now:
        result = LookupResult(
          isWorked: true, 
          isWorkedBand: true, 
          isWorkedMode: true
        );
        // If found locally in session, we can return early or merge with online data?
        // Usually local session dupe is critical for POTA.
        return result; 
      }
    }

    // 2. Check Online (if not offline)
    if (!_isOfflineMode) {
      try {
        final onlineResult = await WavelogService.checkDupe(callsign, band, mode);
        // Merge? or just return online result?
        return onlineResult;
      } catch (e) {
        // ignore error
      }
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final db = DatabaseService();
    return await db.getUnuploadedSessionQsos();
  }

  Future<void> flushQueue(int stationProfileId, Function(int, int) onProgress) async {
    final queue = await getQueue();
    if (queue.isEmpty) return;

    int total = queue.length;
    int current = 0;

    for (var row in queue) {
      final qso = SessionQso.fromMap(row);
      
      // Parse RST back
      // Since we stored them as strings "59" or "599", we need to reconstruct RstReport.
      // This is a bit tricky if we lost the components (R, S, T).
      // Assuming RstReport.parse or similar exists or we reconstruct simple version.
      // Let's assume standard 59/599 for now or simple parsing.
      
      RstReport rstS = _parseRst(qso.rstSent);
      RstReport rstR = _parseRst(qso.rstRcvd);

      bool success = await WavelogService.postQso(
        callsign: qso.callsign,
        band: qso.band,
        mode: qso.mode,
        freq: qso.freq,
        timeOn: qso.timestamp,
        rstSent: rstS,
        rstRcvd: rstR,
        grid: qso.grid,
        name: qso.name,
        qth: qso.qth,
        state: qso.state,
        country: qso.country,
        potaList: qso.potaRef,
        sotaRef: qso.sotaRef,
        overrideStationId: stationProfileId
      );

      if (success) {
        await DatabaseService().markSessionQsoUploaded(qso.id!);
      }
      
      current++;
      onProgress(current, total);
    }
    notifyListeners();
  }

  RstReport _parseRst(String rst) {
    // Basic parser. 
    try {
      if (rst.length == 2) {
        return RstReport()..r = double.parse(rst[0])..s = double.parse(rst[1]);
      } else if (rst.length == 3) {
        return RstReport()..r = double.parse(rst[0])..s = double.parse(rst[1])..t = double.parse(rst[2]);
      }
    } catch (e) {
      // Fallback
    }
    return RstReport()..r=5..s=9;
  }
}
