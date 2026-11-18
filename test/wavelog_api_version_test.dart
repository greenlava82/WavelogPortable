import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_portable/models/rst_report.dart';
import 'package:wavelog_portable/services/wavelog_endpoint.dart';
import 'package:wavelog_portable/services/wavelog_service.dart';

const v1Key = 'cl1234567890abc';
const v2Key = 'wl2_abcdef0123456789';

void main() {
  group('WavelogEndpoint', () {
    test('detects key version by the wl2_ prefix', () {
      expect(WavelogEndpoint.versionForKey(v1Key), WavelogApiVersion.v1);
      expect(WavelogEndpoint.versionForKey(v2Key), WavelogApiVersion.v2);
      expect(WavelogEndpoint.versionForKey('  $v2Key  '), WavelogApiVersion.v2);
    });

    test('reduces any pasted URL to the install root', () {
      for (final raw in [
        'https://log.example.com',
        'https://log.example.com/',
        'https://log.example.com/index.php',
        'https://log.example.com/index.php/api',
        'https://log.example.com/index.php/api/',
        'https://log.example.com/index.php/api/v2',
        'https://log.example.com/index.php/api/v2/',
        'https://log.example.com/api/v2',
        '  https://log.example.com/  ',
      ]) {
        expect(WavelogEndpoint.normalizeBaseUrl(raw), 'https://log.example.com', reason: raw);
      }
      expect(WavelogEndpoint.normalizeBaseUrl('https://example.com/wavelog/index.php/api'),
          'https://example.com/wavelog');
    });

    test('picks the API root and auth style for the key', () {
      final v1 = WavelogEndpoint('https://log.example.com/index.php/api/v2', v1Key);
      expect(v1.apiRoot, 'https://log.example.com/index.php/api');
      expect(v1.headers.containsKey('Authorization'), isFalse);

      final v2 = WavelogEndpoint('https://log.example.com/', v2Key);
      expect(v2.apiRoot, 'https://log.example.com/index.php/api/v2');
      expect(v2.headers['Authorization'], 'Bearer $v2Key');
    });

    test('Settings description', () {
      expect(describeWavelogKey('https://log.example.com', ''), '');
      expect(describeWavelogKey('https://log.example.com', v1Key),
          'API v1 key\nEndpoint: https://log.example.com/index.php/api');
      expect(describeWavelogKey('https://log.example.com/', v2Key),
          'API v2 key\nEndpoint: https://log.example.com/index.php/api/v2\n'
          'Needs scopes: station:read, qso:read, qso:write, lookup:read');
      expect(describeWavelogKey('', v2Key),
          'API v2 key\nNeeds scopes: station:read, qso:read, qso:write, lookup:read');
    });
  });

  group('requests', () {
    late List<http.Request> sent;
    late http.Response Function(http.Request) reply;
    late MockClient wavelog;

    void prefs(String key) => SharedPreferences.setMockInitialValues({
          'wavelog_url': 'https://log.example.com/',
          'wavelog_key': key,
          'wavelog_station_id': '7',
          'my_callsign': 'K1GLV',
          'my_grid': 'FN42',
        });

    setUp(() {
      sent = [];
      reply = (_) => http.Response('{}', 200);
      wavelog = MockClient((r) async {
        sent.add(r);
        return reply(r);
      });
    });

    Future<int> post() => http.runWithClient(
          () => WavelogService.postQso(
            callsign: 'W1AW',
            band: '20m',
            mode: 'FreeDV',
            freq: 14.236,
            timeOn: DateTime.utc(2026, 11, 18, 12),
            rstSent: RstReport(),
            rstRcvd: RstReport(),
          ),
          () => wavelog,
        );

    test('v1 QSO upload: key in body, /api/qso', () async {
      prefs(v1Key);
      await post();
      final r = sent.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://log.example.com/index.php/api/qso');
      expect(r.headers.containsKey('Authorization'), isFalse);
      final body = jsonDecode(r.body);
      expect(body['key'], v1Key);
      expect(body['type'], 'adif');
      expect(body['station_profile_id'], 7);
      expect(body['string'], contains('<SUBMODE:6>FREEDV'));
    });

    test('v2 QSO upload: Bearer header, /api/v2/qso, ADIF import, no key in body', () async {
      prefs(v2Key);
      reply = (_) => http.Response('{"data":{"parsed":1,"imported":1}}', 201);
      expect(await post(), 201);
      final r = sent.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://log.example.com/index.php/api/v2/qso');
      expect(r.headers['Authorization'], 'Bearer $v2Key');
      final body = jsonDecode(r.body);
      expect(body.containsKey('key'), isFalse);
      expect(body['import_type'], 'adif');
      expect(body['station_profile_id'], 7);
      expect(body['adif'], contains('<MODE:12>DIGITALVOICE<SUBMODE:6>FREEDV'));
    });

    test('v1 worked-before lookup', () async {
      prefs(v1Key);
      reply = (_) => http.Response('{"call_worked":true,"call_worked_band":true,"call_worked_band_mode":false}', 200);
      final result = await http.runWithClient(
          () => WavelogService.checkDupe('W1AW', '20m', 'FreeDV'), () => wavelog);
      final r = sent.single;
      expect(r.url.toString(), 'https://log.example.com/index.php/api/private_lookup');
      expect(jsonDecode(r.body)['mode'], 'DIGITALVOICE');
      expect(result.isWorked, isTrue);
      expect(result.isWorkedBand, isTrue);
      expect(result.isWorkedMode, isFalse);
    });

    test('v2 worked-before lookup reads the data envelope', () async {
      prefs(v2Key);
      reply = (_) => http.Response(
          '{"data":{"call_worked":true,"call_worked_band":false,"call_worked_band_mode":false},"meta":{}}', 200);
      final result = await http.runWithClient(
          () => WavelogService.checkDupe('W1AW', '20m', 'FreeDV'), () => wavelog);
      final r = sent.single;
      expect(r.method, 'GET');
      expect(r.url.path, '/index.php/api/v2/lookup');
      expect(r.url.queryParameters,
          {'callsign': 'W1AW', 'band': '20m', 'mode': 'DIGITALVOICE', 'detail': 'full'});
      expect(r.headers['Authorization'], 'Bearer $v2Key');
      expect(result.isWorked, isTrue);
      expect(result.isWorkedBand, isFalse);
    });

    test('v2 station list', () async {
      reply = (_) => http.Response(
          '{"data":[{"id":1,"name":"Home"},{"id":7,"name":"Portable"}],"meta":{}}', 200);
      final (stations, error) = await http.runWithClient(
          () => WavelogService.fetchStationsWithError('https://log.example.com/index.php/api', v2Key),
          () => wavelog);
      final r = sent.single;
      expect(r.method, 'GET');
      expect(r.url.toString(), 'https://log.example.com/index.php/api/v2/station');
      expect(r.headers['Authorization'], 'Bearer $v2Key');
      expect(error, isNull);
      expect(stations, [
        {'id': '1', 'name': 'Home'},
        {'id': '7', 'name': 'Portable'},
      ]);
    });

    test('v2 station list surfaces a missing-scope error', () async {
      reply = (_) => http.Response(
          '{"error":{"code":"insufficient_scope","message":"Token is missing the required scope: station:read"}}', 403);
      final (stations, error) = await http.runWithClient(
          () => WavelogService.fetchStationsWithError('https://log.example.com', v2Key), () => wavelog);
      expect(stations, isEmpty);
      expect(error, 'Token is missing the required scope: station:read');
    });

    test('v1 station list', () async {
      reply = (_) => http.Response('[{"station_id":"3","station_profile_name":"Home"}]', 200);
      final (stations, error) = await http.runWithClient(
          () => WavelogService.fetchStationsWithError('https://log.example.com', v1Key), () => wavelog);
      final r = sent.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://log.example.com/index.php/api/station_info');
      expect(jsonDecode(r.body)['key'], v1Key);
      expect(error, isNull);
      expect(stations, [{'id': '3', 'name': 'Home'}]);
    });
  });
}
