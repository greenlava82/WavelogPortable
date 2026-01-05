import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

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
}