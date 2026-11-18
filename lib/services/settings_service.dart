import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../models/activity_ref.dart';

class AppSettings {
  static const String keyMyCallsign = 'my_callsign';
  static const String keyMyGrid = 'my_grid';
  static const String keyWavelogUrl = 'wavelog_url';
  static const String keyWavelogKey = 'wavelog_key';
  static const String keyWavelogStationId = 'wavelog_station_id';
  static const String keyHamQthUser = 'hamqth_user';
  static const String keyHamQthPass = 'hamqth_pass';
  static const String keyActiveModes = 'active_modes';
  static const String keyLastBand = 'last_band';
  static const String keyLastFreq = 'last_freq';
  static const String keyLastMode = 'last_mode';
  static const String keyOfflineMode = 'offline_mode';
  static const String keyPotaDownloadedAt = 'pota_downloaded_at';
  static const String keyLastActivities = 'last_activities';

  static Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String> getString(String key, {String defaultValue = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? defaultValue;
  }

  static Future<void> saveModes(List<String> modes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyActiveModes, modes);
  }

  static Future<List<String>> getModes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyActiveModes) ?? defaultModes;
  }

  static Future<void> saveRadioState(String band, double freq, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLastBand, band);
    await prefs.setDouble(keyLastFreq, freq);
    await prefs.setString(keyLastMode, mode);
  }

  static Future<Map<String, dynamic>> getLastRadioState() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'band': prefs.getString(keyLastBand),
      'freq': prefs.getDouble(keyLastFreq),
      'mode': prefs.getString(keyLastMode),
    };
  }

  /// Parks/summits attached to the most recently saved contact, so the next
  /// contact (e.g. a second operator at the same activation) can reuse them.
  static Future<void> saveLastActivities(List<ActivityRef> refs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLastActivities, jsonEncode(refs.map((r) => r.toJson()).toList()));
  }

  static Future<List<ActivityRef>> getLastActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyLastActivities);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ActivityRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((r) => r.reference.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
