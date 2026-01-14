import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// 引入刚刚写的组件和详情页
import '../widgets/map_bubble.dart';
import '../../detail/pages/detail_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final List<LatLng> _locations = [
    const LatLng(39.9042, 116.4074),
    const LatLng(39.9082, 116.4014),
    const LatLng(39.9000, 116.4100),
  ];

  int? _expandedIndex;

  // Cache scale factors for each marker
  final Map<int, double> _scaleFactors = {};

  @override
  void initState() {
    super.initState();
    // Initialize all scale factors to 1.0
    for (int i = 0; i < _locations.length; i++) {
      _scaleFactors[i] = 1.0;
    }
  }

  // Calculate scale factor based on distance from screen center
  void _updateScaleFactors() {
    try {
      final camera = _mapController.camera;
      final context = this.context;
      final screenSize = MediaQuery.of(context).size;

      for (int i = 0; i < _locations.length; i++) {
        final markerPosition = _locations[i];

        // Get marker's screen position
        final markerPoint = camera.latLngToScreenPoint(markerPosition);

        // Calculate screen center
        final centerX = screenSize.width / 2;
        final centerY = screenSize.height / 2;

        // Calculate distance from center
        final dx = markerPoint.x - centerX;
        final dy = markerPoint.y - centerY;
        final distance = (dx * dx + dy * dy).abs().toDouble();

        // Calculate max distance (screen diagonal / 2)
        final maxDistance =
            (screenSize.width * screenSize.width +
                screenSize.height * screenSize.height) /
            4;

        // Normalize distance (0 at center, 1 at corners)
        final normalizedDistance = (distance / maxDistance).clamp(0.0, 1.0);

        // Apply exponential decay for smooth scaling
        // Scale from 1.0 (center) to 0.3 (edges)
        final scaleFactor =
            0.3 + (0.7 * (1.0 - normalizedDistance * normalizedDistance));

        _scaleFactors[i] = scaleFactor.clamp(0.3, 1.0);
      }

      setState(() {});
    } catch (e) {
      print('Scale update error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(39.9042, 116.4074),
            initialZoom: 15.0,
            onTap: (_, __) {
              if (_expandedIndex != null) {
                setState(() => _expandedIndex = null);
              }
            },
            onMapEvent: (event) {
              // Update scale factors when map moves
              _updateScaleFactors();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: _locations.asMap().entries.map((entry) {
                final index = entry.key;
                final point = entry.value;
                final isExpanded = _expandedIndex == index;
                final scaleFactor = _scaleFactors[index] ?? 1.0;

                return Marker(
                  point: point,
                  width: 300,
                  height: 300,
                  alignment: Alignment.topCenter,
                  child: MapBubbleWidget(
                    isExpanded: isExpanded,
                    scaleFactor: scaleFactor,
                    onTap: () {
                      if (isExpanded) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => const DetailPage()),
                        );
                      } else {
                        setState(() => _expandedIndex = index);
                        _mapController.move(point, 16);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }
}
