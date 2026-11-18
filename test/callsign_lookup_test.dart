import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_portable/locator.dart';
import 'package:wavelog_portable/services/callsign_lookup.dart';
import 'package:wavelog_portable/services/database_service.dart';

const url = 'https://log.example.com';
const v2Key = 'wl2_abcdef0123456789';
const v1Key = 'cl1234567890abc';

class _FakeDb extends DatabaseService {
  _FakeDb() : super.create();
  final Map<String, Map<String, dynamic>> cache = {};
  @override
  Future<Map<String, dynamic>?> getCachedCallsign(String callsign) async => cache[callsign];
  @override
  Future<void> cacheCallsign(Map<String, dynamic> profile) async => cache[profile['callsign']] = profile;
  @override
  Future<List<Map<String, dynamic>>> getOfflineQsos() async => [];
}

/// What Wavelog's v2 lookup returns: DXCC, your last contact's details,
/// and (when asked and set up) the server's callbook data.
Map<String, dynamic> wavelogData({Map<String, dynamic>? callbook, String name = '', String grid = ''}) => {
      'callsign': 'JA1RL',
      'dxcc': 'JAPAN',
      'dxcc_lat': '36',
      'dxcc_long': '138',
      'name': name,
      'gridsquare': grid,
      'location': name.isEmpty ? '' : 'Tokyo',
      'state': '',
      'call_worked': name.isNotEmpty,
      'callbook': ?callbook,
    };

const hamqth = {
  'callsign': 'JA1RL',
  'name': 'Japan Amateur Radio League',
  'city': 'Toshima',
  'state': '',
  'gridsquare': 'PM95ur',
  'lat': '35.73',
  'long': '139.72',
  'dxcc': 339,
  'source': 'HamQTH',
};

const qrzXml = '<QRZDatabase><Callsign><call>JA1RL</call><fname>JARL</fname><name>HQ</name>'
    '<addr2>Toshima</addr2><country>Japan</country><grid>PM95ur</grid>'
    '<lat>35.7</lat><lon>139.7</lon></Callsign></QRZDatabase>';

void main() {
  late _FakeDb db;
  late List<http.Request> sent;

  setUp(() async {
    await locator.reset();
    db = _FakeDb();
    locator.registerSingleton<DatabaseService>(db);
    sent = [];
  });

  Future<HamProfile> lookup(Map<String, Object> prefs, http.Response Function(http.Request) server,
      {bool offline = false}) {
    SharedPreferences.setMockInitialValues(prefs);
    return http.runWithClient(
      () => CallsignLookup.fetch('JA1RL', offline: offline),
      () => MockClient((r) async {
        sent.add(r);
        return server(r);
      }),
    );
  }

  http.Response wavelog(Map<String, dynamic> data, {bool v2 = true}) =>
      http.Response(jsonEncode(v2 ? {'data': data} : data), 200);

  test('uses the callbook on the Wavelog server, and caches it', () async {
    final p = await lookup({'wavelog_url': url, 'wavelog_key': v2Key},
        (_) => wavelog(wavelogData(callbook: hamqth)));
    expect(p.name, 'Japan Amateur Radio League');
    expect(p.city, 'Toshima');
    expect(p.country, 'Japan'); // HamQTH has no country; Wavelog's DXCC name
    expect(p.grid, 'PM95ur');
    expect(p.lat, 35.73);
    expect(p.lon, 139.72);
    expect(db.cache['JA1RL']?['name'], 'Japan Amateur Radio League');

    final r = sent.single;
    expect(r.url.path, '/index.php/api/v2/lookup');
    expect(r.url.queryParameters, {'callsign': 'JA1RL', 'detail': 'full', 'callbook': 'true'});
  });

  test('v1 key: asks private_lookup for callbook data too', () async {
    final p = await lookup({'wavelog_url': url, 'wavelog_key': v1Key},
        (_) => wavelog(wavelogData(callbook: hamqth), v2: false));
    expect(p.name, 'Japan Amateur Radio League');
    final r = sent.single;
    expect(r.method, 'POST');
    expect(r.url.path, '/index.php/api/private_lookup');
    expect(jsonDecode(r.body), {'key': v1Key, 'callsign': 'JA1RL', 'callbook': true});
  });

  http.Response qrz(http.Request r, {bool found = true}) {
    if (r.url.queryParameters.containsKey('username')) {
      return http.Response('<QRZDatabase><Session><Key>abc</Key></Session></QRZDatabase>', 200);
    }
    return http.Response(found ? qrzXml : '<QRZDatabase><Session><Error>Not found: JA1RL</Error></Session></QRZDatabase>', 200);
  }

  test('QRZ login set: QRZ first (full name), Wavelog not asked', () async {
    final p = await lookup({
      'wavelog_url': url, 'wavelog_key': v2Key, 'hamqth_user': 'me', 'hamqth_pass': 'pw',
    }, (r) => r.url.host == 'log.example.com' ? wavelog(wavelogData(callbook: hamqth)) : qrz(r));
    expect(p.name, 'JARL HQ');
    expect(p.country, 'Japan');
    expect(sent.where((r) => r.url.host == 'log.example.com'), isEmpty);
  });

  test('QRZ login set but QRZ doesn\'t know the call: Wavelog\'s callbook', () async {
    final p = await lookup({
      'wavelog_url': url, 'wavelog_key': v2Key, 'hamqth_user': 'me', 'hamqth_pass': 'pw',
    }, (r) => r.url.host == 'log.example.com' ? wavelog(wavelogData(callbook: hamqth)) : qrz(r, found: false));
    expect(p.name, 'Japan Amateur Radio League');
  });

  test('expired QRZ session: logs in again once, not forever', () async {
    var searches = 0;
    final p = await lookup({'hamqth_user': 'me', 'hamqth_pass': 'pw'}, (r) {
      if (r.url.queryParameters.containsKey('username')) {
        return http.Response('<QRZDatabase><Session><Key>abc</Key></Session></QRZDatabase>', 200);
      }
      searches++;
      return http.Response('<QRZDatabase><Session><Error>Session Timeout</Error></Session></QRZDatabase>', 200);
    });
    expect(p.name, 'Unknown');
    expect(searches, 2);
  });

  test('Wavelog\'s callbook can\'t find it either: last-contact fallback', () async {
    final p = await lookup({'wavelog_url': url, 'wavelog_key': v2Key},
        (_) => wavelog(wavelogData(name: 'Taro', callbook: {'error': {'0': 'Callsign not found'}, 'gridsquare': ''})));
    expect(p.name, 'Taro');
  });

  test('no callbook anywhere: falls back to your last contact with the call', () async {
    final p = await lookup({'wavelog_url': url, 'wavelog_key': v2Key},
        (_) => wavelog(wavelogData(name: 'Taro', grid: 'PM95')));
    expect(p.name, 'Taro');
    expect(p.city, 'Tokyo');
    expect(p.grid, 'PM95');
    expect(p.country, 'Japan');
    expect(db.cache, isEmpty); // nothing new learned, so nothing cached
  });

  test('never worked and no callbook: just the country', () async {
    final p = await lookup({'wavelog_url': url, 'wavelog_key': v2Key}, (_) => wavelog(wavelogData()));
    expect(p.name, 'Unknown');
    expect(p.country, 'Japan');
  });

  test('a cached lookup beats the last-contact fallback', () async {
    db.cache['JA1RL'] = {'callsign': 'JA1RL', 'name': 'Cached Name', 'grid': 'PM95ur'};
    final p = await lookup({'wavelog_url': url, 'wavelog_key': v2Key},
        (_) => wavelog(wavelogData(name: 'Taro')));
    expect(p.name, 'Cached Name');
  });

  test('offline: no network, cache only', () async {
    db.cache['JA1RL'] = {'callsign': 'JA1RL', 'name': 'Cached Name'};
    final p = await lookup({'wavelog_url': url, 'wavelog_key': v2Key},
        (_) => throw StateError('no network'), offline: true);
    expect(p.name, 'Cached Name');
    expect(sent, isEmpty);
  });

  test('server unreachable: cache, then empty', () async {
    final p = await lookup({'wavelog_url': url, 'wavelog_key': v2Key}, (_) => http.Response('oops', 500));
    expect(p.name, 'Unknown');
  });

  test('multi-word DXCC names read naturally', () async {
    final d = wavelogData()..['dxcc'] = 'UNITED STATES OF AMERICA';
    final p = await lookup({'wavelog_url': url, 'wavelog_key': v2Key}, (_) => wavelog(d));
    expect(p.country, 'United States of America');
  });
}
