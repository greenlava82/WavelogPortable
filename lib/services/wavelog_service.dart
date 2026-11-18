// FILE: lib/services/wavelog_service.dart
// ==============================
import 'dart:convert';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:logging/logging.dart';
import 'settings_service.dart';
import '../models/rst_report.dart';
import '../models/lookup_result.dart';
import '../services/database_service.dart';
import '../utils/adif_mode.dart';
import 'wavelog_endpoint.dart';

class WavelogService {
  static final Logger _logger = Logger('WavelogService');
  
  static Future<void> flushOfflineQueue() async {
    final db = DatabaseService();
    List<Map<String, dynamic>> queue = await db.getOfflineQsos();
    
    if (queue.isEmpty) return;
    
    _logger.info("FLUSH: Found ${queue.length} pending QSOs. Retrying...");
    
    // Legacy queue: rows hold complete v1 request bodies, so always resend to v1.
    final baseUrl = WavelogEndpoint.normalizeBaseUrl(await AppSettings.getString(AppSettings.keyWavelogUrl));
    final Uri apiUri = Uri.parse("$baseUrl/index.php/api/qso");

    for (var row in queue) {
      try {
        
        final response = await http.post(
          apiUri,
          headers: {"Content-Type": "application/json"},
          body: row['payload'], // We can resend the exact string we saved
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          _logger.info("FLUSH: QSO ID ${row['id']} Uploaded Successfully!");
          // Delete from local DB immediately upon success
          await db.deleteOfflineQso(row['id']);
        } else {
          _logger.warning("FLUSH: Failed ID ${row['id']} with ${response.statusCode}. Stopping flush.");
          // If one fails, stop trying to preserve order and battery
          break; 
        }
      } catch (e) {
        _logger.severe("FLUSH: Network error ($e). Stopping.");
        break;
      }
    }
  }

  /// Station profiles for the Settings picker. Returns an empty list on any
  /// failure; use [fetchStationsWithError] to also get the reason.
  static Future<List<Map<String, String>>> fetchStations(String baseUrl, String apiKey) async {
    final (stations, _) = await fetchStationsWithError(baseUrl, apiKey);
    return stations;
  }

  static Future<(List<Map<String, String>>, String?)> fetchStationsWithError(String baseUrl, String apiKey) async {
    final ep = WavelogEndpoint(baseUrl, apiKey);
    if (!ep.isConfigured) return (<Map<String, String>>[], 'Enter URL and Key first');

    try {
      if (ep.isV2) {
        final response = await http.get(ep.uri('station'), headers: ep.headers);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body)['data'];
          if (data is List) {
            return (
              data.map<Map<String, String>>((s) => {
                'id': s['id'].toString(),
                'name': (s['name'] ?? 'Station ${s['id']}').toString(),
              }).toList(),
              null,
            );
          }
        }
        return (<Map<String, String>>[], _v2Error(response));
      }

      var response = await http.post(
        ep.uri('station_info'),
        headers: ep.headers,
        body: jsonEncode({"key": ep.apiKey}),
      );

      if (response.statusCode == 401 || response.statusCode == 404 || response.statusCode == 405) {
        response = await http.get(ep.uri('station_info/${ep.apiKey}'));
      }

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return (
            decoded.map<Map<String, String>>((json) {
              return {
                'id': json['station_id'].toString(),
                'name': json['station_profile_name'].toString(),
              };
            }).toList(),
            null,
          );
        }
      }
      return (<Map<String, String>>[], 'Wavelog returned HTTP ${response.statusCode}');
    } catch (e) {
      _logger.severe("Error fetching stations: $e");
      return (<Map<String, String>>[], 'Could not reach Wavelog');
    }
  }

  /// Human-readable message from a v2 error envelope:
  /// {"error": {"code": "...", "message": "..."}}
  static String _v2Error(http.Response response) {
    try {
      final message = jsonDecode(response.body)['error']?['message'];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return 'Wavelog returned HTTP ${response.statusCode}';
  }

  static Future<int> postQso({
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
    String? comment,
    int? overrideStationId, // Optional override
  }) async {
    
    String baseUrl = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String apiKey = await AppSettings.getString(AppSettings.keyWavelogKey);
    String stationIdStr = await AppSettings.getString(AppSettings.keyWavelogStationId);
    String myGrid = await AppSettings.getString(AppSettings.keyMyGrid); 
    String stationCall = await AppSettings.getString(AppSettings.keyMyCallsign);

    final ep = WavelogEndpoint(baseUrl, apiKey);
    if (!ep.isConfigured) return 0;

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
    final adifMode = AdifMode.fromAppMode(mode);
    add("MODE", adifMode.mode);
    if (adifMode.submode != null) add("SUBMODE", adifMode.submode!);
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
    if (comment != null && comment.isNotEmpty) add("COMMENT", comment);
    
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

    _logger.fine("------------------------------------------------");
    _logger.fine("DEBUG ADIF PAYLOAD:");
    _logger.fine(adif.toString());
    _logger.fine("------------------------------------------------");

    // v1 takes the key in the body; v2 takes it in the Authorization header
    // and imports ADIF via import_type=adif. Both return 200/201 on success.
    final Map<String, dynamic> payload = ep.isV2
        ? {
            "station_profile_id": stationProfileId,
            "import_type": "adif",
            "adif": adif.toString(),
          }
        : {
            "key": ep.apiKey,
            "station_profile_id": stationProfileId,
            "type": "adif",
            "string": adif.toString(),
          };

    _logger.fine("--- POST QSO DEBUG ---");
    _logger.fine("URL: ${ep.uri('qso')} (API ${ep.version.name})");
    _logger.fine("Station ID: $stationProfileId");
    _logger.fine("----------------------");

    try {
      final response = await http.post(
        ep.uri('qso'),
        headers: ep.headers,
        body: jsonEncode(payload),
      );

      _logger.fine("Response Code: ${response.statusCode}");
      _logger.fine("Response Body: ${response.body}");

      return response.statusCode;
    } catch (e) {
      // NETWORK ERROR (No internet, timeout)
      _logger.severe("NETWORK ERROR: $e");
      return 0;
    }
  }

  static Future<LookupResult> checkDupe(String callsign, String band, String mode) async {
    String baseUrl = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String apiKey = await AppSettings.getString(AppSettings.keyWavelogKey);

    final ep = WavelogEndpoint(baseUrl, apiKey);
    if (!ep.isConfigured) return LookupResult();

    // Wavelog matches worked-before on the ADIF MODE column only
    final adifMode = AdifMode.fromAppMode(mode).mode;

    try {
      final http.Response response;
      if (ep.isV2) {
        response = await http.get(
          ep.uri('lookup', {
            'callsign': callsign,
            'band': band,
            'mode': adifMode,
            'detail': 'full',
          }),
          headers: ep.headers,
        );
      } else {
        response = await http.post(
          ep.uri('private_lookup'),
          headers: ep.headers,
          body: jsonEncode({
            "key": ep.apiKey,
            "callsign": callsign,
            "band": band,
            "mode": adifMode,
          }),
        );
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        // v2 wraps results in {"data": ...}; v1 returns them at the top level
        final data = ep.isV2 ? decoded['data'] : decoded;
        return LookupResult(
          isWorked: data['call_worked'] ?? false,
          isWorkedBand: data['call_worked_band'] ?? false,
          isWorkedMode: data['call_worked_band_mode'] ?? false,
        );
      }
    } catch (e) {
      _logger.severe("Lookup Error: $e");
    }
    return LookupResult();
  }
}