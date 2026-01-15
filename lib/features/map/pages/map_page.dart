import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../widgets/map_bubble.dart';
import '../../detail/pages/detail_page.dart';
import '../../../presentation/providers/post_provider.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  int? _expandedIndex;

  // Cache scale factors for each marker
  final Map<int, double> _scaleFactors = {};

  @override
  void initState() {
    super.initState();
  }

  // Calculate scale factor based on distance from screen center
  void _updateScaleFactors(MapCamera camera) {
    try {
      final mapSize = camera.size;
      if (mapSize.x == 0 || mapSize.y == 0) {
        return;
      }

      final posts = context.read<PostProvider>().posts;

      for (int i = 0; i < posts.length; i++) {
        final markerPosition = LatLng(
          posts[i].location.latitude,
          posts[i].location.longitude,
        );

        // Get marker's screen position
        final markerPoint = camera.latLngToScreenPoint(markerPosition);

        // Calculate screen center based on map widget size
        final centerX = mapSize.x / 2;
        final centerY = mapSize.y / 2;

        // Calculate distance from center
        final dx = markerPoint.x - centerX;
        final dy = markerPoint.y - centerY;
        final distance = math.sqrt(dx * dx + dy * dy);

        // Calculate max distance (screen diagonal / 2)
        final maxDistance =
            math.sqrt(mapSize.x * mapSize.x + mapSize.y * mapSize.y) / 2;

        // Normalize distance (0 at center, 1 at corners)
        final normalizedDistance = (distance / maxDistance).clamp(0.0, 1.0);

        // Apply exponential decay for smooth scaling
        // Scale from 1.0 (center) to 0.3 (edges)
        final scaleFactor = 0.3 + (0.7 * (1.0 - normalizedDistance));

        _scaleFactors[i] = scaleFactor.clamp(0.3, 1.0);
      }

      setState(() {});
    } catch (e) {
      print('Scale update error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostProvider>(
      builder: (context, postProvider, child) {
        if (postProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (postProvider.error != null) {
          return Center(child: Text('Error: ${postProvider.error}'));
        }

        final posts = postProvider.posts;

        // Initialize scale factors if not already done
        if (_scaleFactors.isEmpty && posts.isNotEmpty) {
          for (int i = 0; i < posts.length; i++) {
            _scaleFactors[i] = 1.0;
          }
        }

        if (posts.isEmpty) {
          return const Center(child: Text('No posts found'));
        }

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  posts[0].location.latitude,
                  posts[0].location.longitude,
                ),
                initialZoom: 15.0,
                onTap: (_, __) {
                  if (_expandedIndex != null) {
                    setState(() => _expandedIndex = null);
                  }
                },
                onMapEvent: (event) {
                  // Update scale factors when map moves
                  _updateScaleFactors(event.camera);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(
                  markers: posts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final post = entry.value;
                    final isExpanded = _expandedIndex == index;
                    final scaleFactor = _scaleFactors[index] ?? 1.0;

                    return Marker(
                      point: LatLng(
                        post.location.latitude,
                        post.location.longitude,
                      ),
                      width: 300,
                      height: 300,
                      alignment: Alignment.topCenter,
                      child: MapBubbleWidget(
                        isExpanded: isExpanded,
                        scaleFactor: scaleFactor,
                        post: post,
                        onTap: () {
                          if (isExpanded) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => DetailPage(postId: post.id),
                              ),
                            );
                          } else {
                            setState(() => _expandedIndex = index);
                            _mapController.move(
                              LatLng(
                                post.location.latitude,
                                post.location.longitude,
                              ),
                              16,
                            );
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
      },
    );
  }
}
