import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class HamProfile {
  final String callsign;
  final String name;
  final String licenseClass;
  final String city;
  final String state;
  final String country;
  final String grid;

  HamProfile({
    required this.callsign,
    required this.name,
    required this.licenseClass,
    required this.city,
    required this.state,
    required this.country,
    required this.grid,
  });

  factory HamProfile.empty() {
    return HamProfile(
      callsign: "---",
      name: "Not Found",
      licenseClass: "---",
      city: "---",
      state: "---",
      country: "---",
      grid: "---",
    );
  }

  factory HamProfile.fromCallook(Map<String, dynamic> json) {
    final current = json['current'] ?? {};
    final address = json['address'] ?? {};
    final location = json['location'] ?? {};

    String displayClass = 'Unknown';
    String type = (json['type'] ?? '').toString().toUpperCase();
    if (['CLUB', 'MILITARY', 'RACES', 'TRUSTEE'].contains(type)) {
      displayClass = type;
    } else if (current['operClass'] != null) {
      displayClass = current['operClass'];
    }

    return HamProfile(
      callsign: current['callsign'] ?? 'Unknown',
      name: json['name'] ?? 'Unknown',
      licenseClass: displayClass,
      city: (address['line2'] != null) ? address['line2'].toString().split(',')[0] : 'Unknown',
      state: (address['line2'] != null) ? address['line2'].toString().split(',')[1].trim().split(' ')[0] : 'Unknown',
      country: "USA",
      grid: location['gridsquare'] ?? 'Unknown',
    );
  }

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
    );
  }
}

class CallsignLookup {
  static String? _qrzSessionKey;

  static Future<HamProfile> fetch(String callsign) async {
    // 1. Try Callook for US calls (Faster, Free)
    if (_isLikelyUS(callsign)) {
      try {
        HamProfile profile = await _fetchCallook(callsign);
        if (profile.name != "Not Found") return profile;
      } catch (e) {
        // Fallback to QRZ
      }
    }

    // 2. Fallback to QRZ (Global)
    return await _fetchQrz(callsign);
  }

  static bool _isLikelyUS(String call) {
    return RegExp(r'^[AKNW][a-zA-Z]?[0-9][a-zA-Z]*$').hasMatch(call.toUpperCase());
  }

  static Future<HamProfile> _fetchCallook(String callsign) async {
    final url = Uri.parse('https://callook.info/$callsign/json');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'VALID') {
        return HamProfile.fromCallook(data);
      }
    }
    return HamProfile.empty();
  }

  static Future<HamProfile> _fetchQrz(String callsign) async {
    String user = await AppSettings.getString(AppSettings.keyHamQthUser);
    String pass = await AppSettings.getString(AppSettings.keyHamQthPass);

    if (user.isEmpty || pass.isEmpty) return HamProfile.empty();

    if (_qrzSessionKey == null) {
      bool loggedIn = await _performQrzLogin(user, pass);
      if (!loggedIn) return HamProfile.empty();
    }

    try {
      final url = Uri.parse("https://xmldata.qrz.com/xml/current/?s=$_qrzSessionKey&callsign=$callsign");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        String xml = response.body;

        if (xml.contains('<Error>')) {
           if (xml.toLowerCase().contains('session') || xml.toLowerCase().contains('expired')) {
             _qrzSessionKey = null;
             if (await _performQrzLogin(user, pass)) {
               return _fetchQrz(callsign); // Retry
             }
           }
           return HamProfile.empty();
        }

        if (xml.contains('<call>')) {
           return HamProfile.fromQrzXml(xml);
        }
      }
    } catch (e) {
      // Network Error
    }
    return HamProfile.empty();
  }

  static Future<bool> _performQrzLogin(String user, String pass) async {
    try {
      final url = Uri.parse("https://xmldata.qrz.com/xml/current/?username=$user&password=$pass");
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final RegExp keyRegex = RegExp(r'<Key>(.*?)</Key>');
        final match = keyRegex.firstMatch(response.body);
        if (match != null) {
          _qrzSessionKey = match.group(1);
          return true;
        }
      }
    } catch (e) {
      // Login Error
    }
    return false;
  }
}