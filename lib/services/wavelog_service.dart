// FILE: lib/services/wavelog_service.dart
// ==============================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import '../models/rst_report.dart';
import '../models/lookup_result.dart';
import '../services/database_service.dart';

class WavelogService {
  
  static Future<void> flushOfflineQueue() async {
    final db = DatabaseService();
    List<Map<String, dynamic>> queue = await db.getOfflineQsos();
    
    if (queue.isEmpty) return;
    
    print("FLUSH: Found ${queue.length} pending QSOs. Retrying...");
    
    String baseUrl = await AppSettings.getString(AppSettings.keyWavelogUrl);
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    final Uri apiUri = Uri.parse("$baseUrl/qso");

    for (var row in queue) {
      try {
        
        final response = await http.post(
          apiUri,
          headers: {"Content-Type": "application/json"},
          body: row['payload'], // We can resend the exact string we saved
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          print("FLUSH: QSO ID ${row['id']} Uploaded Successfully!");
          // Delete from local DB immediately upon success
          await db.deleteOfflineQso(row['id']);
        } else {
          print("FLUSH: Failed ID ${row['id']} with ${response.statusCode}. Stopping flush.");
          // If one fails, stop trying to preserve order and battery
          break; 
        }
      } catch (e) {
        print("FLUSH: Network error ($e). Stopping.");
        break;
      }
    }
  }

  static Future<List<Map<String, String>>> fetchStations(String baseUrl, String apiKey) async {
    if (baseUrl.isEmpty || apiKey.isEmpty) return [];
    
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    apiKey = apiKey.trim(); 

    final Uri postUri = Uri.parse("$baseUrl/station_info");

    try {
      var response = await http.post(
        postUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"key": apiKey}),
      );

      if (response.statusCode == 401 || response.statusCode == 404 || response.statusCode == 405) {
        final Uri getUri = Uri.parse("$baseUrl/station_info/$apiKey");
        response = await http.get(getUri);
      }

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map<Map<String, String>>((json) {
            return {
              'id': json['station_id'].toString(),
              'name': json['station_profile_name'].toString(),
            };
          }).toList();
        }
      }
    } catch (e) {
      print("Error fetching stations: $e");
    }
    return [];
  }

  static Future<bool> postQso({
    required String callsign,
    required String band,
    required String mode,
    required double freq,
    required DateTime timeOn,
    required RstReport rstSent,
    required RstReport rstRcvd,
    String? grid, 
    String? name,
    String? potaList,
    String? sotaRef,
  }) async {
    
    String baseUrl = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String apiKey = await AppSettings.getString(AppSettings.keyWavelogKey);
    String stationIdStr = await AppSettings.getString(AppSettings.keyWavelogStationId);
    String myGrid = await AppSettings.getString(AppSettings.keyMyGrid); 
    String stationCall = await AppSettings.getString(AppSettings.keyMyCallsign);

    if (baseUrl.isEmpty || apiKey.isEmpty) return false; 

    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    apiKey = apiKey.trim();

    final Uri apiUri = Uri.parse("$baseUrl/qso");
    
    int stationProfileId = -1;
    if (stationIdStr.isNotEmpty) {
      int? parsedId = int.tryParse(stationIdStr);
      if (parsedId != null) stationProfileId = parsedId;
    }

    // Build ADIF
    bool isCW = mode == 'CW';
    String qsoDate = "${timeOn.year}${timeOn.month.toString().padLeft(2,'0')}${timeOn.day.toString().padLeft(2,'0')}";
    String timeOnStr = "${timeOn.hour.toString().padLeft(2,'0')}${timeOn.minute.toString().padLeft(2,'0')}${timeOn.second.toString().padLeft(2,'0')}";

    StringBuffer adif = StringBuffer();
    void add(String tag, String value) {
      if (value.isNotEmpty) adif.write("<$tag:${value.length}>$value");
    }

    add("CALL", callsign.toUpperCase());
    add("BAND", band);
    add("MODE", mode);
    add("FREQ", freq.toString());
    add("QSO_DATE", qsoDate);
    add("TIME_ON", timeOnStr);
    add("RST_SENT", rstSent.formatted(isCW));
    add("RST_RCVD", rstRcvd.formatted(isCW));
    add("STATION_CALLSIGN", stationCall);
    add("MY_GRIDSQUARE", myGrid);
    
    if (grid != null && grid != "---") add("GRIDSQUARE", grid);
    if (name != null && name != "Not Found") add("NAME", name);
    
    // --- UPDATED: Use Application-Specific tags for Wavelog ---
    
    // POTA_REF is commonly used by Wavelog/HamRS to populate the specific column
    if (potaList != null && potaList.isNotEmpty) {
      add("POTA_REF", potaList); 
    }

    // SOTA_REF is the standard ADIF tag
    if (sotaRef != null && sotaRef.isNotEmpty) {
      add("SOTA_REF", sotaRef);   
    }
    
    adif.write("<EOR>"); 

    print("------------------------------------------------");
    print("DEBUG ADIF PAYLOAD:");
    print(adif.toString());
    print("------------------------------------------------");

    Map<String, dynamic> payload = {
      "key": apiKey,
      "station_profile_id": stationProfileId,
      "type": "adif",
      "string": adif.toString() 
    };

try {
      final response = await http.post(
        apiUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // SUCCESS!
        // Since we are online, this is a great time to send any old logs
        flushOfflineQueue(); 
        return true;
      } else {
        // API Error (Auth failure, etc) - Do NOT queue if key is wrong, only 5xx errors?
        // For simplicity, we assume 500s or Timeouts are temporary.
        print("UPLOAD FAILED: ${response.statusCode}");
        await DatabaseService().saveOfflineQso(payload);
        return false; 
      }
    } catch (e) {
      // NETWORK ERROR (No internet, timeout)
      print("NETWORK ERROR: $e - Queuing offline");
      await DatabaseService().saveOfflineQso(payload);
      return false; // Return false so UI knows it wasn't *live* uploaded
    }
  }

  static Future<LookupResult> checkDupe(String callsign, String band, String mode) async {
    String baseUrl = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String apiKey = await AppSettings.getString(AppSettings.keyWavelogKey);

    if (baseUrl.isEmpty || apiKey.isEmpty) return LookupResult();
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);

    final Uri apiUri = Uri.parse("$baseUrl/private_lookup");

    Map<String, dynamic> payload = {
      "key": apiKey,
      "callsign": callsign,
      "band": band,
      "mode": mode
    };

    try {
      final response = await http.post(
        apiUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LookupResult(
          isWorked: data['call_worked'] ?? false,
          isWorkedBand: data['call_worked_band'] ?? false,
          isWorkedMode: data['call_worked_band_mode'] ?? false,
        );
      }
    } catch (e) {
      print("Lookup Error: $e");
    }
    return LookupResult();
  }
}