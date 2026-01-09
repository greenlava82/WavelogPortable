// FILE: lib/services/callsign_lookup.dart
// ==============================
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
      name: "Not Found",
      licenseClass: "---",
      city: "---",
      state: "---",
      country: "---",
      grid: "---",
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

  static Future<HamProfile> fetch(String callsign) async {
    // Simplified: Always use QRZ (Removed Callook fallback)
    return await _fetchQrz(callsign);
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