import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_portable/config/theme.dart';
import 'package:wavelog_portable/models/rst_report.dart';
import 'package:wavelog_portable/services/wavelog_service.dart';
import 'package:wavelog_portable/utils/adif_mode.dart';

void main() {
  group('AdifMode', () {
    test('FreeDV maps to DIGITALVOICE / FREEDV', () {
      final m = AdifMode.fromAppMode('FreeDV');
      expect(m.mode, 'DIGITALVOICE');
      expect(m.submode, 'FREEDV');
    });

    test('other modes pass through unchanged with no submode', () {
      final m = AdifMode.fromAppMode('SSB');
      expect(m.mode, 'SSB');
      expect(m.submode, isNull);
    });

    test('FreeDV is offered as a loggable mode', () {
      expect(masterModeList, contains('FreeDV'));
    });
  });

  group('Wavelog requests', () {
    late List<Map<String, dynamic>> sent;
    late MockClient wavelog;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'wavelog_url': 'http://test.com',
        'wavelog_key': 'test_key',
        'wavelog_station_id': '1',
        'my_callsign': 'K1GLV',
        'my_grid': 'FN42',
      });
      sent = [];
      wavelog = MockClient((request) async {
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{}', 200);
      });
    });

    Future<void> postFreeDvQso() => WavelogService.postQso(
          callsign: 'W1AW',
          band: '20m',
          mode: 'FreeDV',
          freq: 14.236,
          timeOn: DateTime.utc(2026, 11, 18, 12, 0, 0),
          rstSent: RstReport(),
          rstRcvd: RstReport(),
        );

    test('FreeDV QSO is uploaded as MODE=DIGITALVOICE, SUBMODE=FREEDV', () async {
      await http.runWithClient(postFreeDvQso, () => wavelog);

      final adif = sent.single['string'] as String;
      expect(adif, contains('<MODE:12>DIGITALVOICE'));
      expect(adif, contains('<SUBMODE:6>FREEDV'));
      expect(adif, isNot(contains('FreeDV')));
    });

    test('SSB QSO has no SUBMODE tag', () async {
      await http.runWithClient(
        () => WavelogService.postQso(
          callsign: 'W1AW',
          band: '20m',
          mode: 'SSB',
          freq: 14.250,
          timeOn: DateTime.utc(2026, 11, 18, 12, 0, 0),
          rstSent: RstReport(),
          rstRcvd: RstReport(),
        ),
        () => wavelog,
      );

      final adif = sent.single['string'] as String;
      expect(adif, contains('<MODE:3>SSB'));
      expect(adif, isNot(contains('SUBMODE')));
    });

    test('worked-before lookup for FreeDV asks Wavelog about DIGITALVOICE', () async {
      await http.runWithClient(
        () => WavelogService.checkDupe('W1AW', '20m', 'FreeDV'),
        () => wavelog,
      );

      expect(sent.single['mode'], 'DIGITALVOICE');
    });
  });
}
