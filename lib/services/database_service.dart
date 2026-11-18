// FILE: lib/services/database_service.dart
// ==============================
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'database_constants.dart';
import '../locator.dart';
import '../utils/park_ref.dart';
import 'settings_service.dart';

class DatabaseService {
  // Factory that returns the singleton from Locator
  factory DatabaseService() => locator<DatabaseService>();

  // Actual constructor used by Locator
  DatabaseService.create();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'ham_logger_refs.db');
    return await openDatabase(
      path,
      // INCREASE VERSION to trigger upgrade
      version: 5, 
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add the new table if upgrading from version 1
          await db.execute('''
            CREATE TABLE ${DatabaseConstants.tableOfflineQsos} (
              ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
              ${DatabaseConstants.colPayload} TEXT,
              ${DatabaseConstants.colTimestamp} INTEGER
            )
          ''');
        }
        if (oldVersion < 3) {
           await db.execute('''
            CREATE TABLE ${DatabaseConstants.tableSessions} (
              ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
              ${DatabaseConstants.colName} TEXT,
              ${DatabaseConstants.colStartTime} INTEGER,
              ${DatabaseConstants.colEndTime} INTEGER,
              ${DatabaseConstants.colIsActive} INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE ${DatabaseConstants.tableSessionQsos} (
              ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
              ${DatabaseConstants.colSessionId} INTEGER,
              ${DatabaseConstants.colCallsign} TEXT,
              ${DatabaseConstants.colBand} TEXT,
              ${DatabaseConstants.colMode} TEXT,
              ${DatabaseConstants.colFreq} REAL,
              ${DatabaseConstants.colTimestamp} INTEGER,
              ${DatabaseConstants.colRstSent} TEXT,
              ${DatabaseConstants.colRstRcvd} TEXT,
              ${DatabaseConstants.colPotaRef} TEXT,
              ${DatabaseConstants.colSotaRef} TEXT,
              ${DatabaseConstants.colGrid} TEXT,
              ${DatabaseConstants.colName} TEXT,
              ${DatabaseConstants.colQth} TEXT,
              ${DatabaseConstants.colState} TEXT,
              ${DatabaseConstants.colCountry} TEXT,
              ${DatabaseConstants.colIsUploaded} INTEGER,
              FOREIGN KEY(${DatabaseConstants.colSessionId}) REFERENCES ${DatabaseConstants.tableSessions}(${DatabaseConstants.colId})
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE ${DatabaseConstants.tableCallsignCache} (
              ${DatabaseConstants.colCallsign} TEXT PRIMARY KEY,
              ${DatabaseConstants.colName} TEXT,
              license_class TEXT,
              city TEXT,
              ${DatabaseConstants.colState} TEXT,
              ${DatabaseConstants.colCountry} TEXT,
              ${DatabaseConstants.colGrid} TEXT,
              lat REAL,
              lon REAL,
              ${DatabaseConstants.colTimestamp} INTEGER
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE ${DatabaseConstants.tableSessionQsos} ADD COLUMN ${DatabaseConstants.colComment} TEXT');
        }
      },
    );
  }

  // Helper to create all tables (used in onCreate)
  Future<void> _createTables(Database db) async {
    await db.execute('CREATE TABLE ${DatabaseConstants.tablePota} (${DatabaseConstants.colReference} TEXT PRIMARY KEY, ${DatabaseConstants.colName} TEXT, ${DatabaseConstants.colLocation} TEXT)');
    await db.execute('CREATE TABLE ${DatabaseConstants.tableSota} (${DatabaseConstants.colReference} TEXT PRIMARY KEY, ${DatabaseConstants.colName} TEXT, ${DatabaseConstants.colRegion} TEXT)');
    // NEW TABLE
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableOfflineQsos} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colPayload} TEXT,
        ${DatabaseConstants.colTimestamp} INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSessions} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colName} TEXT,
        ${DatabaseConstants.colStartTime} INTEGER,
        ${DatabaseConstants.colEndTime} INTEGER,
        ${DatabaseConstants.colIsActive} INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableSessionQsos} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colSessionId} INTEGER,
        ${DatabaseConstants.colCallsign} TEXT,
        ${DatabaseConstants.colBand} TEXT,
        ${DatabaseConstants.colMode} TEXT,
        ${DatabaseConstants.colFreq} REAL,
        ${DatabaseConstants.colTimestamp} INTEGER,
        ${DatabaseConstants.colRstSent} TEXT,
        ${DatabaseConstants.colRstRcvd} TEXT,
        ${DatabaseConstants.colPotaRef} TEXT,
        ${DatabaseConstants.colSotaRef} TEXT,
        ${DatabaseConstants.colGrid} TEXT,
        ${DatabaseConstants.colName} TEXT,
        ${DatabaseConstants.colQth} TEXT,
        ${DatabaseConstants.colState} TEXT,
        ${DatabaseConstants.colCountry} TEXT,
        ${DatabaseConstants.colComment} TEXT,
        ${DatabaseConstants.colIsUploaded} INTEGER,
        FOREIGN KEY(${DatabaseConstants.colSessionId}) REFERENCES ${DatabaseConstants.tableSessions}(${DatabaseConstants.colId})
      )
    ''');
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCallsignCache} (
        ${DatabaseConstants.colCallsign} TEXT PRIMARY KEY,
        ${DatabaseConstants.colName} TEXT,
        license_class TEXT,
        city TEXT,
        ${DatabaseConstants.colState} TEXT,
        ${DatabaseConstants.colCountry} TEXT,
        ${DatabaseConstants.colGrid} TEXT,
        lat REAL,
        lon REAL,
        ${DatabaseConstants.colTimestamp} INTEGER
      )
    ''');
  }

  // --- SESSION METHODS ---

  Future<int> createSession(Map<String, dynamic> session) async {
    final db = await database;
    // Deactivate others? Maybe not enforced by DB, but by logic.
    return await db.insert(DatabaseConstants.tableSessions, session);
  }

  Future<int> closeSession(int id, int endTime) async {
    final db = await database;
    return await db.update(
      DatabaseConstants.tableSessions, 
      {DatabaseConstants.colIsActive: 0, DatabaseConstants.colEndTime: endTime},
      where: '${DatabaseConstants.colId} = ?', 
      whereArgs: [id]
    );
  }

  Future<Map<String, dynamic>?> getActiveSession() async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query(
      DatabaseConstants.tableSessions,
      where: '${DatabaseConstants.colIsActive} = 1',
      orderBy: '${DatabaseConstants.colStartTime} DESC',
      limit: 1,
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    final db = await database;
    return await db.query(
      DatabaseConstants.tableSessions,
      orderBy: '${DatabaseConstants.colStartTime} DESC',
    );
  }

  Future<void> deleteSession(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(DatabaseConstants.tableSessionQsos, where: '${DatabaseConstants.colSessionId} = ?', whereArgs: [id]);
      await txn.delete(DatabaseConstants.tableSessions, where: '${DatabaseConstants.colId} = ?', whereArgs: [id]);
    });
  }

  Future<void> reopenSession(int id) async {
    final db = await database;
    await db.update(
      DatabaseConstants.tableSessions,
      {DatabaseConstants.colIsActive: 1, DatabaseConstants.colEndTime: null},
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertSessionQso(Map<String, dynamic> qso) async {
    final db = await database;
    return await db.insert(DatabaseConstants.tableSessionQsos, qso);
  }
  
  Future<void> updateSessionQso(Map<String, dynamic> qso) async {
    final db = await database;
    await db.update(
      DatabaseConstants.tableSessionQsos, 
      qso,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [qso[DatabaseConstants.colId]]
    );
  }

  Future<List<Map<String, dynamic>>> getSessionQsos(int sessionId) async {
    final db = await database;
    return await db.query(
      DatabaseConstants.tableSessionQsos,
      where: '${DatabaseConstants.colSessionId} = ?',
      whereArgs: [sessionId],
      orderBy: '${DatabaseConstants.colTimestamp} DESC'
    );
  }

  /// Newest QSOs logged on this phone, across all sessions.
  Future<List<Map<String, dynamic>>> getRecentSessionQsos(int limit) async {
    final db = await database;
    return await db.query(
      DatabaseConstants.tableSessionQsos,
      orderBy: '${DatabaseConstants.colTimestamp} DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> searchSessionQsos(int sessionId, String query) async {
    final db = await database;
    return await db.query(
      DatabaseConstants.tableSessionQsos,
      where: '${DatabaseConstants.colSessionId} = ? AND (${DatabaseConstants.colCallsign} LIKE ? OR ${DatabaseConstants.colName} LIKE ? OR ${DatabaseConstants.colComment} LIKE ?)',
      whereArgs: [sessionId, '%$query%', '%$query%', '%$query%'],
      orderBy: '${DatabaseConstants.colTimestamp} DESC'
    );
  }

  Future<int> getSessionQsoCount(int sessionId) async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseConstants.tableSessionQsos} WHERE ${DatabaseConstants.colSessionId} = ?', 
      [sessionId]
    )) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getUnuploadedSessionQsos() async {
    final db = await database;
    return await db.query(
      DatabaseConstants.tableSessionQsos,
      where: '${DatabaseConstants.colIsUploaded} = 0',
      orderBy: '${DatabaseConstants.colTimestamp} ASC'
    );
  }

  Future<int> markSessionQsoUploaded(int id) async {
    final db = await database;
    return await db.update(
      DatabaseConstants.tableSessionQsos,
      {DatabaseConstants.colIsUploaded: 1},
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id]
    );
  }

  Future<void> deleteSessionQso(int id) async {
    final db = await database;
    await db.delete(DatabaseConstants.tableSessionQsos, where: '${DatabaseConstants.colId} = ?', whereArgs: [id]);
  }
  
  Future<bool> checkSessionDupe(int sessionId, String callsign, String band, String mode) async {
    final db = await database;
    final res = await db.query(
      DatabaseConstants.tableSessionQsos,
      where: '${DatabaseConstants.colSessionId} = ? AND ${DatabaseConstants.colCallsign} = ? AND ${DatabaseConstants.colBand} = ? AND ${DatabaseConstants.colMode} = ?',
      whereArgs: [sessionId, callsign, band, mode]
    );
    return res.isNotEmpty;
  }

  // --- OFFLINE QUEUE METHODS ---

  Future<void> saveOfflineQso(Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert(DatabaseConstants.tableOfflineQsos, {
      DatabaseConstants.colPayload: jsonEncode(payload),
      DatabaseConstants.colTimestamp: DateTime.now().millisecondsSinceEpoch,
    });
    developer.log("OFFLINE: QSO Saved to Queue");
  }

  Future<List<Map<String, dynamic>>> getOfflineQsos() async {
    final db = await database;
    return await db.query(DatabaseConstants.tableOfflineQsos, orderBy: '${DatabaseConstants.colTimestamp} ASC');
  }

  Future<void> deleteOfflineQso(int id) async {
    final db = await database;
    await db.delete(DatabaseConstants.tableOfflineQsos, where: '${DatabaseConstants.colId} = ?', whereArgs: [id]);
  }
  
  Future<int> getOfflineQueueSize() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableOfflineQsos}')) ?? 0;
  }

  // --- CALLSIGN CACHE METHODS ---

  Future<Map<String, dynamic>?> getCachedCallsign(String callsign) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableCallsignCache,
      where: '${DatabaseConstants.colCallsign} = ?',
      whereArgs: [callsign.toUpperCase()],
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> cacheCallsign(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      DatabaseConstants.tableCallsignCache,
      {
        ...profile,
        DatabaseConstants.colCallsign: profile['callsign'].toString().toUpperCase(),
        DatabaseConstants.colTimestamp: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- SEARCH FUNCTIONS ---

  Future<List<Map<String, String>>> searchPota(String query) async {
    final db = await database;
    // Also match loosely typed references ("US10073", "US 10073", "K-1234")
    final ref = normalizeParkRef(query) ?? query;
    const t = DatabaseConstants.tablePota;
    const r = DatabaseConstants.colReference;
    const n = DatabaseConstants.colName;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT * FROM $t WHERE $r LIKE ? OR $r LIKE ? OR $n LIKE ? '
      // Exact reference match first, so it can't be pushed out by the limit
      'ORDER BY CASE WHEN $r = ? THEN 0 ELSE 1 END, $r LIMIT 20',
      ['%$query%', '%$ref%', '%$query%', ref.toUpperCase()],
    );
    return maps.map((e) => {
      'ref': e[DatabaseConstants.colReference] as String,
      'name': e[DatabaseConstants.colName] as String,
      'loc': e[DatabaseConstants.colLocation] as String,
      'type': 'POTA'
    }).toList();
  }

  Future<List<Map<String, String>>> searchSota(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableSota,
      where: '${DatabaseConstants.colReference} LIKE ? OR ${DatabaseConstants.colName} LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 20,
    );
    return maps.map((e) => {
      'ref': e[DatabaseConstants.colReference] as String,
      'name': e[DatabaseConstants.colName] as String,
      'loc': e[DatabaseConstants.colRegion] as String,
      'type': 'SOTA'
    }).toList();
  }

  Future<int> getPotaCount() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tablePota}')) ?? 0;
  }

  // --- DOWNLOAD & UPDATE FUNCTIONS ---

  Future<void> updateAllDatabases(Function(String) onStatus) async {
    await updatePota(onStatus);
    await updateSota(onStatus);
  }

  Future<void> updatePota(Function(String) onStatus) async {
    final db = await database;
    onStatus("Downloading POTA Database...");
    
    // Official POTA CSV Source
    final url = Uri.parse('https://pota.app/all_parks.csv');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        onStatus("Parsing POTA Data...");
        
        // POTA uses \r\n (Windows style) or mix. Default converter usually handles this best.
        List<List<dynamic>> rows = const CsvToListConverter().convert(response.body);
        
        if (rows.isEmpty) return;

        onStatus("Updating POTA Tables...");
        
        await db.transaction((txn) async {
          await txn.delete(DatabaseConstants.tablePota);
          Batch batch = txn.batch();
          
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.length > 4) {
              batch.insert(DatabaseConstants.tablePota, {
                DatabaseConstants.colReference: row[0].toString(), // "K-0001"
                DatabaseConstants.colName: row[1].toString(),      // "Name of Park"
                DatabaseConstants.colLocation: row[4].toString()   // "GA"
              });
            }
          }
          await batch.commit(noResult: true);
        });
        await AppSettings.saveString(AppSettings.keyPotaDownloadedAt, DateTime.now().toIso8601String());
        developer.log("POTA Update Complete: ${rows.length} parks.");
      }
    } catch (e) {
      developer.log("Error updating POTA: $e");
      onStatus("Error updating POTA: $e");
    }
  }

  Future<void> updateSota(Function(String) onStatus) async {
    final db = await database;
    onStatus("Downloading SOTA Database...");

    // Official SOTA CSV Source
    final url = Uri.parse('https://storage.sota.org.uk/summitslist.csv');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        onStatus("Parsing SOTA Data...");
        
        // SOTA strictly uses \n (Unix style).
        // FIX: We explicitly set eol to \n here.
        List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(response.body);

        if (rows.isEmpty) return;
        
        onStatus("Updating SOTA Tables...");

        await db.transaction((txn) async {
          await txn.delete(DatabaseConstants.tableSota);
          Batch batch = txn.batch();

          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.length > 3) {
              batch.insert(DatabaseConstants.tableSota, {
                DatabaseConstants.colReference: row[0].toString(), // "W1/HA-001"
                DatabaseConstants.colName: row[3].toString(),      // "Mount Washington"
                DatabaseConstants.colRegion: row[2].toString(),    // "White Mountains"
              });
            }
          }
          await batch.commit(noResult: true);
        });
        developer.log("SOTA Update Complete: ${rows.length} summits.");
      }
    } catch (e) {
      developer.log("Error updating SOTA: $e");
      onStatus("Error updating SOTA: $e");
    }
  }
}