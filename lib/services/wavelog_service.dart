// FILE: lib/services/wavelog_service.dart
// ==============================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import '../models/rst_report.dart';
import '../models/previous_qso.dart';

// Define a simple class to hold the lookup result
class LookupResult {
  final bool isWorked;          // Have I ever worked them?
  final bool isWorkedBand;      // Have I worked them on THIS band?
  final bool isWorkedMode;      // Have I worked them on THIS band & mode? (Strict Dupe)

  LookupResult({this.isWorked = false, this.isWorkedBand = false, this.isWorkedMode = false});
}

class WavelogService {
  
  // --- FETCH STATIONS (Robust: Trims Key + GET Fallback) ---
  static Future<List<Map<String, String>>> fetchStations(String baseUrl, String apiKey) async {
    // 1. Sanitize Inputs
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      print("Wavelog: Missing URL or Key");
      return [];
    }
    
    // Remove trailing slash and spaces
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    apiKey = apiKey.trim(); 

    // 2. Attempt 1: Standard POST request
    final Uri postUri = Uri.parse("$baseUrl/station_info");
    print("Wavelog: Fetching stations (POST) from $postUri");

    try {
      var response = await http.post(
        postUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"key": apiKey}),
      );

      // 3. Attempt 2: GET Fallback (if POST fails)
      if (response.statusCode == 401 || response.statusCode == 404 || response.statusCode == 405) {
        print("POST failed (${response.statusCode}). Retrying with GET method...");
        
        // Wavelog often accepts: /index.php/api/station_info/API_KEY
        final Uri getUri = Uri.parse("$baseUrl/station_info/$apiKey");
        response = await http.get(getUri);
      }

      print("Wavelog Response Code: ${response.statusCode}");
      // print("Wavelog Raw Body: ${response.body}"); // Uncomment to debug raw JSON

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is List) {
          return decoded.map<Map<String, String>>((json) {
            return {
              'id': json['station_id'].toString(),
              'name': json['station_profile_name'].toString(),
            };
          }).toList();
        } else if (decoded is Map) {
          print("Wavelog returned a Map error: $decoded");
        }
      }
    } catch (e) {
      print("Error fetching stations: $e");
    }
    return [];
  }

  // --- POST QSO (Existing Logic + Trim) ---
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
  }) async {
    
    String baseUrl = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String apiKey = await AppSettings.getString(AppSettings.keyWavelogKey);
    String stationIdStr = await AppSettings.getString(AppSettings.keyWavelogStationId);
    String myGrid = await AppSettings.getString(AppSettings.keyMyGrid); 
    String stationCall = await AppSettings.getString(AppSettings.keyMyCallsign);

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      print("Wavelog Error: Missing URL or API Key");
      return false; 
    }

    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    apiKey = apiKey.trim(); // <--- CRITICAL FIX

    final Uri apiUri = Uri.parse("$baseUrl/qso");
    
    int stationProfileId = -1;
    if (stationIdStr.isNotEmpty) {
      int? parsedId = int.tryParse(stationIdStr);
      if (parsedId != null) stationProfileId = parsedId;
    }

    // BUILD RAW ADIF STRING
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
    
    adif.write("<EOR>"); 

    Map<String, dynamic> payload = {
      "key": apiKey,
      "station_profile_id": stationProfileId,
      "type": "adif",
      "string": adif.toString() 
    };

    try {
      print("Wavelog: Sending QSO -> $callsign (Station ID: $stationProfileId)...");
      final response = await http.post(
        apiUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      print("Wavelog Status: ${response.statusCode}");
      // print("Wavelog Body:   ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Wavelog Network Error: $e");
      return false;
    }
  }

  // --- NEW: Private Lookup (Dupe Check) ---
  static Future<LookupResult> checkDupe(String callsign, String band, String mode) async {
    String baseUrl = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String apiKey = await AppSettings.getString(AppSettings.keyWavelogKey);

    if (baseUrl.isEmpty || apiKey.isEmpty) return LookupResult();
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);

    // Construct URL: .../index.php/api/private_lookup
    final Uri apiUri = Uri.parse("$baseUrl/private_lookup");

    Map<String, dynamic> payload = {
      "key": apiKey,
      "callsign": callsign,
      "band": band,
      "mode": mode
    };

    try {
      print("DEBUG: Checking Dupe -> $apiUri");
      final response = await http.post(
        apiUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("DEBUG: Lookup Result: $data");
        
        return LookupResult(
          isWorked: data['call_worked'] ?? false,
          isWorkedBand: data['call_worked_band'] ?? false,
          isWorkedMode: data['call_worked_band_mode'] ?? false,
        );
      } else {
        print("DEBUG: Lookup Failed (${response.statusCode})");
      }
    } catch (e) {
      print("DEBUG: Lookup Error: $e");
    }
    return LookupResult();
  }
}