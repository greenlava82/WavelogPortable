import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_portable/widgets/location_map_dialog.dart';

void main() {
  test('the bundled map has every tile for zoom 0-5, and pubspec lists each zoom', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (var z = 0; z <= offlineMaxZoom; z++) {
      expect(pubspec, contains('- assets/map/$z/'));
      final n = 1 << z;
      for (var x = 0; x < n; x++) {
        for (var y = 0; y < n; y++) {
          final path = offlineTiles
              .replaceAll('{z}', '$z')
              .replaceAll('{x}', '$x')
              .replaceAll('{y}', '$y');
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
    }
  });
}
