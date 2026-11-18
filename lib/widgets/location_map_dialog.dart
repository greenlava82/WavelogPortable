// FILE: lib/widgets/location_map_dialog.dart
// ==============================
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/theme.dart';

/// Esri World Street Map tiles (note the {y}/{x} order).
const String esriStreetTiles =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';

/// The bundled offline map, drawn by tool/render_offline_map.py.
const String offlineTiles = 'assets/map/{z}/{x}_{y}.png';
const int offlineMaxZoom = 5;

class LocationMapDialog extends StatelessWidget {
  final LatLng center;
  final String callsign;
  final String grid;

  const LocationMapDialog({
    super.key,
    required this.center,
    required this.callsign,
    required this.grid,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 400, // Fixed height for the popup
        width: double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 3.5, // Zoom 5 is roughly "Large Region/State" level
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // Disable rotation to keep North up
                ),
              ),
              children: [
                // Bundled low-detail world map (zoom 0-5, English labels),
                // underneath: it's what shows when there's no signal.
                TileLayer(
                  urlTemplate: offlineTiles,
                  tileProvider: AssetTileProvider(),
                  maxNativeZoom: offlineMaxZoom,
                  // Past this it's just a blur of stretched pixels.
                  maxZoom: offlineMaxZoom + 2,
                ),
                // Esri's street map labels places in English everywhere;
                // OSM's standard tiles use each place's local language.
                // Covers the bundled map whenever it loads.
                TileLayer(
                  urlTemplate: esriStreetTiles,
                  userAgentPackageName: 'com.k1glv.wavelogportable',
                  maxNativeZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 80,
                      height: 80,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
            
            // Floating Label at the bottom
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Text(
                  "$callsign @ $grid",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              ),
            ),

            // Attribution (required by Esri's terms)
            const Positioned(
              top: 8,
              left: 8,
              child: _Attribution(),
            ),

            // Close Button
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.8),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Powered by Esri',
        style: TextStyle(fontSize: 10, color: Colors.black87),
      ),
    );
  }
}
