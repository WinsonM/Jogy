import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../widgets/map_bubble.dart';
import '../../detail/pages/detail_page.dart';
import '../../../presentation/providers/post_provider.dart';
import '../../../config/map_config.dart';
import '../../../data/datasources/mock_data_source.dart';

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

  // 用户位置相关
  LatLng? _userLocation;
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 设置 MockDataSource 的中心点为用户位置
      MockDataSource.setCenter(position.latitude, position.longitude);

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _locationLoading = false;
      });

      // 刷新 posts 以使用新的位置
      if (mounted) {
        Provider.of<PostProvider>(context, listen: false).fetchPosts();
      }
    } catch (e) {
      print('获取位置失败: $e');
      setState(() => _locationLoading = false);
    }
  }

  // 计算“理想尖角位置”（用于自动展开判断和点击居中），只依赖屏幕尺寸，
  // 与底部导航栏等 UI 高度解耦，保证以后改导航栏不会影响气泡锚点。
  Offset _expandedBubbleTipTarget(math.Point<double> mapSize) {
    final screenCenterY = mapSize.y / 2;
    // 向上偏移 1/3 屏幕高度
    final upwardOffset = mapSize.y / 7;
    return Offset(
      mapSize.x / 2,
      screenCenterY + _expandedBubbleTipYOffset - upwardOffset,
    );
  }

  Offset _expandedBubbleCenterOffset(math.Point<double> mapSize) {
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
            // 这个气泡是被抑制的（用户刚收起它）
            // 只标记它仍然符合条件，但不参与"最近气泡"的竞选
            suppressedStillEligible = true;
          } else if (distance < minDistance) {
            // 这个气泡不被抑制，且比之前记录的更近
            // 更新为新的候选者
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
    // 位置加载中显示加载指示器
    if (_locationLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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

        // 使用用户位置作为中心，如果获取失败则使用第一个 post 位置
        final mapCenter =
            _userLocation ??
            LatLng(posts[0].location.latitude, posts[0].location.longitude);

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: mapCenter,
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
                  // When user drags the map, clear manual selection to restore auto-expand mode
                  if (event is MapEventMove &&
                      event.source == MapEventSource.onDrag) {
                    if (_manualExpandedIndex != null) {
                      _manualExpandedIndex = null;
                    }
                  }
                  // Update scale factors when map moves
                  _updateScaleFactors(event.camera);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.tileUrl,
                  userAgentPackageName: 'com.example.jogy',
                ),
                // 用户位置标记 - 先渲染，确保不会遮挡展开的气泡
                if (_userLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _userLocation!,
                        width: MapBubbleWidget.collapsedSize,
                        height: MapBubbleWidget.collapsedSize,
                        alignment: Alignment.bottomCenter,
                        child: const _UserLocationMarker(),
                      ),
                    ],
                  ),
                // Posts 气泡 - 后渲染，展开的气泡在最上层
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
                              offset: _expandedBubbleCenterOffset(cameraSize),
                            );
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            // 顶部工具栏：搜索框 + 消息按钮 + 发布按钮
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  // 搜索框 - 占据剩余空间
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // TODO: 打开搜索页面
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(153), // 60% 不透明度
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(20),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 22,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '搜索',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 消息按钮
                  GestureDetector(
                    onTap: () {
                      // TODO: 打开消息页面
                    },
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(153), // 60% 不透明度
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 22,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 发布按钮
                  GestureDetector(
                    onTap: () {
                      // TODO: 打开发布页面
                    },
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(153), // 60% 不透明度
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add,
                            size: 24,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// 用户位置标记 - 使用与气泡缩小时相同的样式，颜色为橙色
class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    const double size = MapBubbleWidget.collapsedSize;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _UserBubblePainter(color: Colors.orange),
      ),
    );
  }
}

// 用户气泡画笔 - 与 MapBubble 缩小状态相同的形状
class _UserBubblePainter extends CustomPainter {
  final Color color;

  _UserBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = _buildCollapsedBubblePath(size);

    // 绘制阴影
    canvas.drawShadow(path, Colors.black.withOpacity(0.15), 10.0, true);
    // 绘制气泡
    canvas.drawPath(path, paint);
  }

  ui.Path _buildCollapsedBubblePath(Size size) {
    final w = size.width;
    final h = size.height;

    // 圆形部分
    final circlePath = ui.Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w / 2, h / 2 - 5), radius: w / 2 - 5),
      );

    // 箭头部分
    final arrowHeight = MapBubbleWidget.arrowHeight;
    final arrow = ui.Path()
      ..moveTo(w / 2 - 8, h - arrowHeight)
      ..lineTo(w / 2, h)
      ..lineTo(w / 2 + 8, h - arrowHeight)
      ..close();

    return ui.Path.combine(ui.PathOperation.union, circlePath, arrow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
