// FILE: lib/services/callsign_lookup.dart
// ==============================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import 'wavelog_endpoint.dart';
import 'wavelog_service.dart';
import 'database_service.dart';

class HamProfile {
  final String callsign;
  final String name;
  final String licenseClass;
  final String city;
  final String state;
  final String country;
  final String grid;
  final double? lat;
  final double? lon;

  HamProfile({
    required this.callsign,
    required this.name,
    required this.licenseClass,
    required this.city,
    required this.state,
    required this.country,
    required this.grid,
    this.lat,
    this.lon,
  });

  factory HamProfile.empty() {
    return HamProfile(
      callsign: "---",
      name: "Unknown", // Changed from "Not Found"
      licenseClass: "---",
      city: "---",
      state: "---",
      country: "---",
      grid: "---",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callsign': callsign,
      'name': name,
      'license_class': licenseClass,
      'city': city,
      'state': state,
      'country': country,
      'grid': grid,
      'lat': lat,
      'lon': lon,
    };
  }

  factory HamProfile.fromMap(Map<String, dynamic> map) {
    return HamProfile(
      callsign: map['callsign'] ?? "---",
      name: map['name'] ?? "Unknown",
      licenseClass: map['license_class'] ?? "---",
      city: map['city'] ?? "---",
      state: map['state'] ?? "---",
      country: map['country'] ?? "---",
      grid: map['grid'] ?? "---",
      lat: map['lat'],
      lon: map['lon'],
    );
  }

  /// Has something worth showing (a name or a grid).
  bool get isFound => (name.isNotEmpty && name != "Unknown" && name != "Not Found") || _validGrid(grid);

  static bool _validGrid(String g) => RegExp(r'^[A-Ra-r]{2}[0-9]{2}').hasMatch(g);

  static double? _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

  static String _str(dynamic v) => v == null || v == false ? '' : '$v'.trim();

  /// "UNITED STATES OF AMERICA" -> "United States of America"
  static String _titleCase(String s) {
    const small = {'of', 'and', 'the', 'de', 'da', 'du'};
    var i = 0;
    return s.toLowerCase().split(' ').map((w) {
      final first = i++ == 0;
      if (w.isEmpty || (!first && small.contains(w))) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  /// From the callbook data Wavelog's lookup returns (`callbook`), when the
  /// server has a callbook set up and found the call. [dxcc] is Wavelog's
  /// country name for the call, used when the callbook has none.
  static HamProfile? fromWavelogCallbook(String callsign, dynamic cb, String dxcc) {
    if (cb is! Map) return null;
    if (_str(cb['error']).isNotEmpty) return null;
    final name = _str(cb['name']);
    final grid = _str(cb['gridsquare']);
    if (name.isEmpty && !_validGrid(grid)) return null;
    final country = _str(cb['country']).isNotEmpty ? _str(cb['country']) : dxcc;
    return HamProfile(
      callsign: _str(cb['callsign']).isNotEmpty ? _str(cb['callsign']).toUpperCase() : callsign,
      name: name.isEmpty ? "Unknown" : name,
      licenseClass: _str(cb['class']).isEmpty ? "---" : _str(cb['class']),
      city: _str(cb['city']),
      state: _str(cb['state']),
      country: country,
      grid: grid,
      lat: _num(cb['lat']),
      lon: _num(cb['long'] ?? cb['lon']),
    );
  }

  /// From what Wavelog knows without a callbook: the name, QTH and grid of
  /// your last contact with the call, and its DXCC country.
  static HamProfile? fromWavelogLogbook(String callsign, Map data, String dxcc) {
    final name = _str(data['name']);
    final grid = _str(data['gridsquare']);
    if (name.isEmpty && !_validGrid(grid) && dxcc.isEmpty) return null;
    return HamProfile(
      callsign: callsign,
      name: name.isEmpty ? "Unknown" : name,
      licenseClass: "---",
      city: _str(data['location']),
      state: _str(data['state']),
      country: dxcc,
      grid: grid,
    );
  }

  // --- PARSE QRZ XML ---
  factory HamProfile.fromQrzXml(String xml) {
    String getTag(String tag) {
      final RegExp regExp = RegExp('<$tag>(.*?)</$tag>');
      final match = regExp.firstMatch(xml);
      return match?.group(1) ?? "";
    }

    String first = getTag('fname');
    String last = getTag('name');
    String fullName = "$first $last".trim();
    if (fullName.isEmpty) fullName = last; 

    return HamProfile(
      callsign: getTag('call').toUpperCase(),
      name: fullName,
      licenseClass: getTag('class'),
      city: getTag('addr2'),
      state: getTag('state'), 
      country: getTag('country'),
      grid: getTag('grid'),
      
      // PARSE COORDINATES
      lat: double.tryParse(getTag('lat')),
      lon: double.tryParse(getTag('lon')),
    );
  }
}

class CallsignLookup {
  static String? _qrzSessionKey;

  /// Name, location and grid for [callsign], tried in this order:
  ///
  /// 1. QRZ directly, when there's a QRZ login in Settings: full names and
  ///    licence class.
  /// 2. The callbook set up on your Wavelog server (QRZ, HamQTH, QRZCQ, ...),
  ///    through Wavelog's lookup API. Wavelog passes on HamQTH's nickname
  ///    field as the name, so that's usually a first name only.
  /// 3. Wavelog's own logbook: your last contact with the call, and its
  ///    country.
  /// 4. This phone's cache of earlier lookups (works offline).
  ///
  /// Online results from 1 and 2 are cached for offline use.
  static Future<HamProfile> fetch(String callsign, {bool offline = false}) async {
    HamProfile? fromLogbook;
    if (!offline) {
      final qrz = await _fetchQrz(callsign);
      if (qrz.isFound) {
        debugPrint('Lookup $callsign: QRZ from the phone');
        return _cache(qrz);
      }

      final wl = await _fetchWavelog(callsign);
      if (wl.callbook != null) return _cache(wl.callbook!);
      fromLogbook = wl.logbook;
    }

    final cachedData = await DatabaseService().getCachedCallsign(callsign);
    if (cachedData != null) return HamProfile.fromMap(cachedData);

    return fromLogbook ?? HamProfile.empty();
  }

  static Future<HamProfile> _cache(HamProfile p) async {
    await DatabaseService().cacheCallsign(p.toMap());
    return p;
  }

  /// Wavelog's lookup, asking it to include its callbook's data.
  static Future<({HamProfile? callbook, HamProfile? logbook})> _fetchWavelog(String callsign) async {
    final ep = WavelogEndpoint(
      await AppSettings.getString(AppSettings.keyWavelogUrl),
      await AppSettings.getString(AppSettings.keyWavelogKey),
    );
    if (!ep.isConfigured) return (callbook: null, logbook: null);
    try {
      final http.Response response;
      if (ep.isV2) {
        response = await http
            .get(ep.uri('lookup', {'callsign': callsign, 'detail': 'full', 'callbook': 'true'}),
                headers: ep.headers)
            .timeout(const Duration(seconds: 12));
      } else {
        response = await http
            .post(ep.uri('private_lookup'),
                headers: ep.headers,
                body: jsonEncode({'key': ep.apiKey, 'callsign': callsign, 'callbook': true}))
            .timeout(const Duration(seconds: 12));
      }
      if (response.statusCode != 200) return (callbook: null, logbook: null);
      final decoded = jsonDecode(response.body);
      final data = ep.isV2 ? decoded['data'] : decoded;
      if (data is! Map) return (callbook: null, logbook: null);
      final dxcc = HamProfile._titleCase(HamProfile._str(data['dxcc']));
      final cb = data['callbook'];
      debugPrint('Lookup $callsign: Wavelog callbook '
          '${cb is Map ? (HamProfile._str(cb['error']).isEmpty ? 'answered (${HamProfile._str(cb['source'])})' : 'error: ${HamProfile._str(cb['error'])}') : 'not returned'}');
      return (
        callbook: HamProfile.fromWavelogCallbook(callsign, data['callbook'], dxcc),
        logbook: HamProfile.fromWavelogLogbook(callsign, data, dxcc),
      );
    } catch (_) {
      return (callbook: null, logbook: null);
    }
  }

  static Future<HamProfile> _fetchQrz(String callsign, {bool retried = false}) async {
    String user = await AppSettings.getString(AppSettings.keyHamQthUser);
    String pass = await AppSettings.getString(AppSettings.keyHamQthPass);

    if (user.isEmpty || pass.isEmpty) return HamProfile.empty();

    if (_qrzSessionKey == null) {
      bool loggedIn = await _performQrzLogin(user, pass);
      if (!loggedIn) {
        debugPrint('Lookup $callsign: QRZ login failed');
        return HamProfile.empty();
      }
    }

    try {
      final url = Uri.parse("https://xmldata.qrz.com/xml/current/?s=$_qrzSessionKey&callsign=$callsign");
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        String xml = response.body;

        final error = RegExp(r'<Error>(.*?)</Error>').firstMatch(xml)?.group(1)?.toLowerCase();
        if (error != null) {
          debugPrint('Lookup $callsign: QRZ says "$error"');
          // "Session Timeout" / "Invalid session key": log in again, once.
          // Anything else (e.g. "Not found: XX1XX") just means no result.
          if (!retried && (error.contains('session') || error.contains('timeout'))) {
            _qrzSessionKey = null;
            if (await _performQrzLogin(user, pass)) {
              return _fetchQrz(callsign, retried: true);
            }
          }
          return HamProfile.empty();
        }

        if (xml.contains('<call>')) {
           WavelogService.flushOfflineQueue();
           return HamProfile.fromQrzXml(xml);
        }
      }
    } catch (e) {
      debugPrint('Lookup $callsign: QRZ request failed: $e');
    }
    return HamProfile.empty();
  }

  static Future<bool> _performQrzLogin(String user, String pass) async {
    try {
      final url = Uri.parse("https://xmldata.qrz.com/xml/current/?username=$user&password=$pass");
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final RegExp keyRegex = RegExp(r'<Key>(.*?)</Key>');
        final match = keyRegex.firstMatch(response.body);
        if (match != null) {
          _qrzSessionKey = match.group(1);
          return true;
        }
      }
    } catch (e) {
      debugPrint('QRZ login request failed: $e');
    }
    return false;
  }
}