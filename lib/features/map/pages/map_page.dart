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
  // 以屏幕几何中心为基准的 Y 方向偏移（尖角位置）。
  // 0 表示尖角在屏幕垂直正中心；负值整体往上移，正值整体往下移。
  // 这里取「往上移动约半个展开气泡高度」，让整块气泡区域落在屏幕视觉中心附近。
  static const double _expandedBubbleTipYOffset =
      -MapBubbleWidget.expandedHeight / 2;

  int? _expandedIndex; // Currently expanded bubble (auto or manual)
  int? _manualExpandedIndex; // Track user manual click
  int? _suppressedAutoIndex; // Prevent immediate auto re-expand after collapse

  // Cache scale factors for each marker
  final Map<int, double> _scaleFactors = {};

  @override
  void initState() {
    super.initState();
  }

  // 计算“理想尖角位置”（用于自动展开判断和点击居中），只依赖屏幕尺寸，
  // 与底部导航栏等 UI 高度解耦，保证以后改导航栏不会影响气泡锚点。
  Offset _expandedBubbleTipTarget(
    math.Point<double> mapSize,
  ) {
    final screenCenterY = mapSize.y / 2;
    return Offset(mapSize.x / 2, screenCenterY + _expandedBubbleTipYOffset);
  }

  Offset _expandedBubbleCenterOffset(
    math.Point<double> mapSize,
  ) {
    // MapController.move 的 offset 是相对于屏幕中心的偏移。
    // 目标位置使用 _expandedBubbleTipTarget 返回的位置（与自动展开一致）。
    final targetTip = _expandedBubbleTipTarget(mapSize);
    final screenCenterY = mapSize.y / 2;
    // 计算偏移：目标位置 - 屏幕中心
    return Offset(0, targetTip.dy - screenCenterY);
  }

  // Calculate scale factor based on distance from screen center
  void _updateScaleFactors(MapCamera camera) {
    try {
      if (camera.size.x == 0 || camera.size.y == 0) {
        return;
      }
      final mapSize = camera.size;

      final posts = context.read<PostProvider>().posts;

      // 自动展开的判定中心与点击居中的尖角目标一致，
      // 只依赖屏幕尺寸，不依赖底部导航栏高度。
      final focusPoint = _expandedBubbleTipTarget(mapSize);
      final centerX = focusPoint.dx;
      final centerY = focusPoint.dy;

      final maxDistance =
          math.sqrt(mapSize.x * mapSize.x + mapSize.y * mapSize.y) / 2;
      final expandBand = MapBubbleWidget.collapsedSize;
      bool needsRebuild = false;
      bool suppressedStillEligible = false;

      // Auto-expansion threshold: 30% of screen width (increased for easier triggering)
      final expansionThreshold = mapSize.x * 0.30;
      int? closestIndex;
      double minDistance = double.infinity;

      for (int i = 0; i < posts.length; i++) {
        final markerPosition = LatLng(
          posts[i].location.latitude,
          posts[i].location.longitude,
        );

        // Get marker's screen position (this is the bubble tip location)
        final markerPoint = camera.latLngToScreenPoint(markerPosition);

        // Calculate distance from marker point to center
        // For auto-expand, we check if the marker enters the center zone
        final dx = markerPoint.x - centerX;
        final dy = markerPoint.y - centerY;
        final distance = math.sqrt(dx * dx + dy * dy);

        // Track closest bubble within threshold
        final isEligible =
            distance < expansionThreshold && dy.abs() <= expandBand;
        if (isEligible) {
          if (i == _suppressedAutoIndex) {
            suppressedStillEligible = true;
          } else if (distance < minDistance) {
            minDistance = distance;
            closestIndex = i;
          }
        }

        // Normalize distance (0 at center, 1 at corners)
        final normalizedDistance = (distance / maxDistance).clamp(0.0, 1.0);

        // Apply exponential decay for smooth scaling
        // Scale from 1.0 (center) to 0.3 (edges)
        final scaleFactor = 0.3 + (0.7 * (1.0 - normalizedDistance));
        final clampedScale = scaleFactor.clamp(0.3, 1.0);
        if ((_scaleFactors[i] ?? 1.0) != clampedScale) {
          needsRebuild = true;
        }
        _scaleFactors[i] = clampedScale;
      }

      if (_suppressedAutoIndex != null && !suppressedStillEligible) {
        _suppressedAutoIndex = null;
      }

      // Auto-expand logic
      if (_manualExpandedIndex == null) {
        // No manual selection - use auto-expand
        if (closestIndex != _expandedIndex) {
          _expandedIndex = closestIndex;
          needsRebuild = true;
        }
      } else {
        // Keep manual selection
        if (_expandedIndex != _manualExpandedIndex) {
          _expandedIndex = _manualExpandedIndex;
          needsRebuild = true;
        }
      }

      if (needsRebuild) {
        setState(() {});
      }
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

        // Sort markers: expanded bubble on top (rendered last)
        final sortedIndices = List<int>.generate(posts.length, (i) => i);
        if (_expandedIndex != null) {
          sortedIndices.sort((a, b) {
            if (a == _expandedIndex) return 1; // Move to end (top layer)
            if (b == _expandedIndex) return -1;
            return 0;
          });
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
                  // Clear manual selection - restore auto-expand mode
                  final collapsedIndex = _expandedIndex;
                  setState(() {
                    _manualExpandedIndex = null;
                    _expandedIndex = null;
                    _suppressedAutoIndex = collapsedIndex;
                  });
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
                  markers: sortedIndices.map((index) {
                    final post = posts[index];
                    final isExpanded = _expandedIndex == index;
                    final scaleFactor = _scaleFactors[index] ?? 1.0;

                    return Marker(
                      point: LatLng(
                        post.location.latitude,
                        post.location.longitude,
                      ),
                      width: MapBubbleWidget.expandedHeight,
                      height: MapBubbleWidget.expandedHeight,
                      alignment:
                          Alignment.bottomCenter, // Tip stays at marker point
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
                            // Manual expand - override auto
                            setState(() {
                              _manualExpandedIndex = index;
                              _expandedIndex = index;
                              _suppressedAutoIndex = null;
                            });
                            final cameraSize = _mapController.camera.size;
                            _mapController.move(
                              LatLng(
                                post.location.latitude,
                                post.location.longitude,
                              ),
                              16,
                              // Center the marker tip within the visible map area.
                              offset: _expandedBubbleCenterOffset(
                                cameraSize,
                              ),
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
