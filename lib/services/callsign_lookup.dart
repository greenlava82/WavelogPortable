// FILE: lib/services/callsign_lookup.dart
// ==============================
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

  // --- FACTORY: FROM CALLOOK (JSON) ---
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

  // --- FACTORY: FROM QRZ XML ---
  factory HamProfile.fromQrzXml(String xml) {
    String getTag(String tag) {
      final RegExp regExp = RegExp('<$tag>(.*?)</$tag>');
      final match = regExp.firstMatch(xml);
      return match?.group(1) ?? "";
    }

    // QRZ Specific Tags
    // <fname> = First Name, <name> = Last Name. 
    // Sometimes people put full name in <name>. Let's combine nicely.
    String first = getTag('fname');
    String last = getTag('name');
    String fullName = "$first $last".trim();
    if (fullName.isEmpty) fullName = last; 

    return HamProfile(
      callsign: getTag('call').toUpperCase(),
      name: fullName,
      licenseClass: getTag('class'), // QRZ actually gives us the class! (E, G, T, etc)
      city: getTag('addr2'),
      state: getTag('state'), 
      country: getTag('country'),
      grid: getTag('grid'),
    );
  }
}

class CallsignLookup {
  // We reuse the HamQTH keys for QRZ since they serve the same purpose (Username/Password)
  // To avoid breaking your Settings file, we just read the same keys.
  static String? _qrzSessionKey;

  static Future<HamProfile> fetch(String callsign) async {
    // 1. STRATEGY: Try Callook for US calls (It's faster and free)
    if (_isLikelyUS(callsign)) {
      try {
        HamProfile profile = await _fetchCallook(callsign);
        if (profile.name != "Not Found") return profile;
      } catch (e) {
        print("Callook failed ($e). Falling back to QRZ...");
      }
    }

    // 2. STRATEGY: Fallback to QRZ XML (Worldwide & Backup)
    return await _fetchQrz(callsign);
  }

  static bool _isLikelyUS(String call) {
    return RegExp(r'^[AKNW][a-zA-Z]?[0-9][a-zA-Z]*$').hasMatch(call.toUpperCase());
  }

  // --- PROVIDER 1: CALLOOK ---
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

  // --- PROVIDER 2: QRZ XML ---
  static Future<HamProfile> _fetchQrz(String callsign) async {
    // REUSING HAMQTH KEYS from Settings so you don't have to rebuild the Settings Screen
    String user = await AppSettings.getString(AppSettings.keyHamQthUser);
    String pass = await AppSettings.getString(AppSettings.keyHamQthPass);

    if (user.isEmpty || pass.isEmpty) {
      print("QRZ skipped: No credentials in Settings.");
      return HamProfile.empty();
    }

    // Ensure Login
    if (_qrzSessionKey == null) {
      bool loggedIn = await _performQrzLogin(user, pass);
      if (!loggedIn) return HamProfile.empty();
    }

    try {
      // QRZ Lookup URL
      final url = Uri.parse("https://xmldata.qrz.com/xml/current/?s=$_qrzSessionKey&callsign=$callsign");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        String xml = response.body;

        // DEBUG PRINT
        print("------------------------------------------------");
        print("QRZ XML RESPONSE FOR $callsign:");
        print(xml); 
        print("------------------------------------------------");

        // Check for Errors / Session Timeout
        if (xml.contains('<Error>')) {
           final RegExp errorRegex = RegExp(r'<Error>(.*?)</Error>');
           final match = errorRegex.firstMatch(xml);
           String errorMsg = match?.group(1)?.toLowerCase() ?? "";
           
           print("QRZ Error: $errorMsg");

           if (errorMsg.contains('session') || errorMsg.contains('expired')) {
             print("QRZ Session Expired. Re-logging...");
             _qrzSessionKey = null;
             if (await _performQrzLogin(user, pass)) {
               return _fetchQrz(callsign); // Retry once
             }
           }
           return HamProfile.empty();
        }

        // Success?
        if (xml.contains('<call>')) {
           return HamProfile.fromQrzXml(xml);
        }
      }
    } catch (e) {
      print("QRZ Network Error: $e");
    }
    return HamProfile.empty();
  }

  static Future<bool> _performQrzLogin(String user, String pass) async {
    try {
      // QRZ Login URL
      final url = Uri.parse("https://xmldata.qrz.com/xml/current/?username=$user&password=$pass");
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final RegExp keyRegex = RegExp(r'<Key>(.*?)</Key>');
        final match = keyRegex.firstMatch(response.body);
        if (match != null) {
          _qrzSessionKey = match.group(1);
          print("QRZ Login Successful.");
          return true;
        } else {
          print("QRZ Login Failed: No Key found in response.");
        }
      }
    } catch (e) {
      print("QRZ Login Network Error: $e");
    }
    return false;
  }
}