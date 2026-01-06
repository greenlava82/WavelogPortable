// FILE: lib/utils/maidenhead.dart
// ==============================
import 'package:latlong2/latlong.dart';

class MaidenheadLocator {
  static LatLng? toLatLng(String grid) {
    if (grid.length < 4) return null;
    
    grid = grid.toUpperCase();
    
    // Validate characters
    if (!RegExp(r'^[A-R]{2}[0-9]{2}').hasMatch(grid)) return null;

    // 1. Fields (First 2 chars, A-R)
    // 'A' is -180 Longitude, -90 Latitude
    double lon = (grid.codeUnitAt(0) - 'A'.codeUnitAt(0)) * 20.0 - 180.0;
    double lat = (grid.codeUnitAt(1) - 'A'.codeUnitAt(0)) * 10.0 - 90.0;

    // 2. Squares (Next 2 chars, 0-9)
    // Each square is 2.0 deg Longitude, 1.0 deg Latitude
    lon += (grid.codeUnitAt(2) - '0'.codeUnitAt(0)) * 2.0;
    lat += (grid.codeUnitAt(3) - '0'.codeUnitAt(0)) * 1.0;

    // 3. Center the point in the square
    // (A 4-char square is 2x1 degrees, so we add 1x0.5 to center it)
    lon += 1.0;
    lat += 0.5;

    return LatLng(lat, lon);
  }
}