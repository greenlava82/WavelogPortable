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
    if (baseUrl.endsWith('/index.php/api')) baseUrl = baseUrl.substring(0, baseUrl.length - 14);
    final Uri apiUri = Uri.parse("$baseUrl/index.php/api/qso");

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
    if (baseUrl.endsWith('/index.php/api')) baseUrl = baseUrl.substring(0, baseUrl.length - 14);
    apiKey = apiKey.trim(); 

    final Uri postUri = Uri.parse("$baseUrl/index.php/api/station_info");

    try {
      var response = await http.post(
        postUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"key": apiKey}),
      );

      if (response.statusCode == 401 || response.statusCode == 404 || response.statusCode == 405) {
        final Uri getUri = Uri.parse("$baseUrl/index.php/api/station_info/$apiKey");
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
    String? qth,
    String? state,
    String? country,
    String? potaList,
    String? sotaRef,
    int? overrideStationId, // Optional override
  }) async {
    
    String baseUrl = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String apiKey = await AppSettings.getString(AppSettings.keyWavelogKey);
    String stationIdStr = await AppSettings.getString(AppSettings.keyWavelogStationId);
    String myGrid = await AppSettings.getString(AppSettings.keyMyGrid); 
    String stationCall = await AppSettings.getString(AppSettings.keyMyCallsign);

    if (baseUrl.isEmpty || apiKey.isEmpty) return false; 

    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    if (baseUrl.endsWith('/index.php/api')) baseUrl = baseUrl.substring(0, baseUrl.length - 14);
    apiKey = apiKey.trim();

    final Uri apiUri = Uri.parse("$baseUrl/index.php/api/qso");
    
    int stationProfileId = -1;
    // Use override if provided, else use settings
    if (overrideStationId != null) {
      stationProfileId = overrideStationId;
    } else if (stationIdStr.isNotEmpty) {
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
    if (qth != null && qth.isNotEmpty) add("QTH", qth);
    if (state != null && state.isNotEmpty) add("STATE", state);
    if (country != null && country.isNotEmpty) add("COUNTRY", country);
    
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

    print("--- POST QSO DEBUG ---");
    print("URL: $apiUri");
    print("Station ID: $stationProfileId");
    print("Payload: ${jsonEncode(payload)}");
    print("----------------------");

    try {
      final response = await http.post(
        apiUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      print("Response Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        // API Error (Auth failure, etc)
        print("UPLOAD FAILED: ${response.statusCode} - ${response.body}");
        return false; 
      }
    } catch (e) {
      // NETWORK ERROR (No internet, timeout)
      print("NETWORK ERROR: $e");
      return false;
    }
  }

  static Future<LookupResult> checkDupe(String callsign, String band, String mode) async {
    String baseUrl = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String apiKey = await AppSettings.getString(AppSettings.keyWavelogKey);

    if (baseUrl.isEmpty || apiKey.isEmpty) return LookupResult();
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    if (baseUrl.endsWith('/index.php/api')) baseUrl = baseUrl.substring(0, baseUrl.length - 14);

    final Uri apiUri = Uri.parse("$baseUrl/index.php/api/private_lookup");

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