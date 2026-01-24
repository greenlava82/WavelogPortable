// FILE: lib/services/database_service.dart
// ==============================
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

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
            CREATE TABLE offline_qsos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              payload TEXT,
              timestamp INTEGER
            )
          ''');
        }
        if (oldVersion < 3) {
           await db.execute('''
            CREATE TABLE sessions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              start_time INTEGER,
              end_time INTEGER,
              is_active INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE session_qsos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id INTEGER,
              callsign TEXT,
              band TEXT,
              mode TEXT,
              freq REAL,
              timestamp INTEGER,
              rst_sent TEXT,
              rst_rcvd TEXT,
              pota_ref TEXT,
              sota_ref TEXT,
              grid TEXT,
              name TEXT,
              qth TEXT,
              state TEXT,
              country TEXT,
              is_uploaded INTEGER,
              FOREIGN KEY(session_id) REFERENCES sessions(id)
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE callsign_cache (
              callsign TEXT PRIMARY KEY,
              name TEXT,
              license_class TEXT,
              city TEXT,
              state TEXT,
              country TEXT,
              grid TEXT,
              lat REAL,
              lon REAL,
              timestamp INTEGER
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE session_qsos ADD COLUMN comment TEXT');
        }
      },
    );
  }

  // Helper to create all tables (used in onCreate)
  Future<void> _createTables(Database db) async {
    await db.execute('CREATE TABLE pota (reference TEXT PRIMARY KEY, name TEXT, location TEXT)');
    await db.execute('CREATE TABLE sota (reference TEXT PRIMARY KEY, name TEXT, region TEXT)');
    // NEW TABLE
    await db.execute('''
      CREATE TABLE offline_qsos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payload TEXT,
        timestamp INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        start_time INTEGER,
        end_time INTEGER,
        is_active INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE session_qsos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        callsign TEXT,
        band TEXT,
        mode TEXT,
        freq REAL,
        timestamp INTEGER,
        rst_sent TEXT,
        rst_rcvd TEXT,
        pota_ref TEXT,
        sota_ref TEXT,
        grid TEXT,
        name TEXT,
        qth TEXT,
        state TEXT,
        country TEXT,
        comment TEXT,
        is_uploaded INTEGER,
        FOREIGN KEY(session_id) REFERENCES sessions(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE callsign_cache (
        callsign TEXT PRIMARY KEY,
        name TEXT,
        license_class TEXT,
        city TEXT,
        state TEXT,
        country TEXT,
        grid TEXT,
        lat REAL,
        lon REAL,
        timestamp INTEGER
      )
    ''');
  }

  // --- SESSION METHODS ---

  Future<int> createSession(Map<String, dynamic> session) async {
    final db = await database;
    // Deactivate others? Maybe not enforced by DB, but by logic.
    return await db.insert('sessions', session);
  }

  Future<int> closeSession(int id, int endTime) async {
    final db = await database;
    return await db.update(
      'sessions', 
      {'is_active': 0, 'end_time': endTime},
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  Future<Map<String, dynamic>?> getActiveSession() async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query(
      'sessions',
      where: 'is_active = 1',
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<int> insertSessionQso(Map<String, dynamic> qso) async {
    final db = await database;
    return await db.insert('session_qsos', qso);
  }
  
  Future<List<Map<String, dynamic>>> getSessionQsos(int sessionId) async {
    final db = await database;
    return await db.query(
      'session_qsos',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC'
    );
  }

  Future<List<Map<String, dynamic>>> getUnuploadedSessionQsos() async {
    final db = await database;
    return await db.query(
      'session_qsos',
      where: 'is_uploaded = 0',
      orderBy: 'timestamp ASC'
    );
  }

  Future<int> markSessionQsoUploaded(int id) async {
    final db = await database;
    return await db.update(
      'session_qsos',
      {'is_uploaded': 1},
      where: 'id = ?',
      whereArgs: [id]
    );
  }

  Future<void> deleteSessionQso(int id) async {
    final db = await database;
    await db.delete('session_qsos', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<bool> checkSessionDupe(int sessionId, String callsign, String band, String mode) async {
    final db = await database;
    final res = await db.query(
      'session_qsos',
      where: 'session_id = ? AND callsign = ? AND band = ? AND mode = ?',
      whereArgs: [sessionId, callsign, band, mode]
    );
    return res.isNotEmpty;
  }

  // --- OFFLINE QUEUE METHODS ---

  Future<void> saveOfflineQso(Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert('offline_qsos', {
      'payload': jsonEncode(payload), // Store the whole JSON blob
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print("OFFLINE: QSO Saved to Queue");
  }

  Future<List<Map<String, dynamic>>> getOfflineQsos() async {
    final db = await database;
    return await db.query('offline_qsos', orderBy: 'timestamp ASC');
  }

  Future<void> deleteOfflineQso(int id) async {
    final db = await database;
    await db.delete('offline_qsos', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<int> getOfflineQueueSize() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM offline_qsos')) ?? 0;
  }

  // --- CALLSIGN CACHE METHODS ---

  Future<Map<String, dynamic>?> getCachedCallsign(String callsign) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'callsign_cache',
      where: 'callsign = ?',
      whereArgs: [callsign.toUpperCase()],
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> cacheCallsign(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      'callsign_cache',
      {
        ...profile,
        'callsign': profile['callsign'].toString().toUpperCase(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- SEARCH FUNCTIONS ---

  Future<List<Map<String, String>>> searchPota(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pota',
      where: 'reference LIKE ? OR name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 20,
    );
    return maps.map((e) => {
      'ref': e['reference'] as String,
      'name': e['name'] as String,
      'loc': e['location'] as String,
      'type': 'POTA'
    }).toList();
  }

  Future<List<Map<String, String>>> searchSota(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sota',
      where: 'reference LIKE ? OR name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 20,
    );
    return maps.map((e) => {
      'ref': e['reference'] as String,
      'name': e['name'] as String,
      'loc': e['region'] as String,
      'type': 'SOTA'
    }).toList();
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
          await txn.delete('pota');
          Batch batch = txn.batch();
          
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.length > 4) {
              batch.insert('pota', {
                'reference': row[0].toString(), // "K-0001"
                'name': row[1].toString(),      // "Name of Park"
                'location': row[4].toString()   // "GA"
              });
            }
          }
          await batch.commit(noResult: true);
        });
        print("POTA Update Complete: ${rows.length} parks.");
      }
    } catch (e) {
      print("Error updating POTA: $e");
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
          await txn.delete('sota');
          Batch batch = txn.batch();

          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.length > 3) {
              batch.insert('sota', {
                'reference': row[0].toString(), // "W1/HA-001"
                'name': row[3].toString(),      // "Mount Washington"
                'region': row[2].toString(),    // "White Mountains"
              });
            }
          }
          await batch.commit(noResult: true);
        });
        print("SOTA Update Complete: ${rows.length} summits.");
      }
    } catch (e) {
      print("Error updating SOTA: $e");
      onStatus("Error updating SOTA: $e");
    }
  }
}