// FILE: lib/services/database_service.dart
// ==============================
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
      version: 1,
      onCreate: (db, version) async {
        // Create POTA Table
        await db.execute('''
          CREATE TABLE pota (
            reference TEXT PRIMARY KEY,
            name TEXT,
            location TEXT
          )
        ''');
        // Create SOTA Table
        await db.execute('''
          CREATE TABLE sota (
            reference TEXT PRIMARY KEY,
            name TEXT,
            region TEXT
          )
        ''');
      },
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