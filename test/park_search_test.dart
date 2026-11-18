import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_portable/utils/park_list_status.dart';
import 'package:wavelog_portable/utils/park_ref.dart';

void main() {
  group('normalizeParkRef', () {
    test('5-digit references in any spacing or case', () {
      expect(normalizeParkRef('US-10073'), 'US-10073');
      expect(normalizeParkRef('US10073'), 'US-10073');
      expect(normalizeParkRef('US 10073'), 'US-10073');
      expect(normalizeParkRef('us10073'), 'US-10073');
      expect(normalizeParkRef('  us - 10073 '), 'US-10073');
    });

    test('old K prefix maps to US', () {
      expect(normalizeParkRef('K-1234'), 'US-1234');
      expect(normalizeParkRef('K1234'), 'US-1234');
      expect(normalizeParkRef('k 10073'), 'US-10073');
    });

    test('other countries keep their prefix', () {
      expect(normalizeParkRef('CA1234'), 'CA-1234');
      expect(normalizeParkRef('ve-1234'), 'VE-1234');
    });

    test('partial references still normalize for as-you-type search', () {
      expect(normalizeParkRef('US100'), 'US-100');
    });

    test('names and bare numbers are left alone', () {
      expect(normalizeParkRef('Blue Hills'), isNull);
      expect(normalizeParkRef('10073'), isNull);
      expect(normalizeParkRef('Route 66'), isNull);
      expect(normalizeParkRef('W1/HA-001'), isNull);
    });
  });

  group('parkListStatus', () {
    final now = DateTime(2026, 11, 18, 15, 0);

    test('no parks downloaded', () {
      expect(
        parkListStatus(downloadedAt: null, parkCount: 0, now: now),
        'Not downloaded yet. Required for offline search',
      );
    });

    test('parks present but date unknown (downloaded before this version)', () {
      expect(
        parkListStatus(downloadedAt: null, parkCount: 106072, now: now),
        '106,072 parks, download date unknown. Re-download to refresh',
      );
    });

    test('downloaded today', () {
      expect(
        parkListStatus(downloadedAt: DateTime(2026, 11, 18, 9, 30), parkCount: 106072, now: now),
        '106,072 parks, downloaded 2026-11-18 (today)',
      );
    });

    test('downloaded a while ago', () {
      expect(
        parkListStatus(downloadedAt: DateTime(2026, 9, 10, 14, 45), parkCount: 98000, now: now),
        '98,000 parks, downloaded 2026-09-10 (69 days ago)',
      );
      expect(
        parkListStatus(downloadedAt: DateTime(2026, 11, 17, 23, 0), parkCount: 5, now: now),
        '5 parks, downloaded 2026-11-17 (1 day ago)',
      );
    });
  });
}
