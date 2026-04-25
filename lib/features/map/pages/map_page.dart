import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../../core/database/database_helper.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:provider/provider.dart';
import '../../../core/map/map_types.dart';
import '../../../core/map/map_controller.dart';
import '../../../core/map/map_widget_builder.dart';
import '../../../core/map/mapbox/mapbox_map_widget_builder.dart';
import '../widgets/map_bubble.dart';
import '../widgets/zoom_arc_control.dart';
import '../clustering/cluster_engine.dart';
import '../clustering/cluster_models.dart';
import '../../detail/pages/detail_page.dart';
import '../../../presentation/providers/post_provider.dart';
import '../../../config/map_config.dart';
import '../../../data/models/post_model.dart';
import '../../../utils/mapbox_language.dart';
import 'package:dio/dio.dart';
import 'search_page.dart';
import '../../scan/pages/scan_page.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../profile/services/browsing_history_service.dart';
import 'location_picker_page.dart';
import '../../../data/models/location_model.dart';
import '../../../widgets/center_toast.dart';
import '../../../widgets/wheel_popover.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  JogyMapController? _jogyMapController;
  // 以屏幕几何中心为基准的 Y 方向偏移（尖角位置）。
  // 0 表示尖角在屏幕垂直正中心；负值整体往上移，正值整体往下移。
  // 这里取「往上移动约半个展开气泡高度」，让整块气泡区域落在屏幕视觉中心附近。
  static const double _expandedBubbleTipYOffset =
      -MapBubbleWidget.expandedHeight / 2;

  int? _expandedIndex; // Currently expanded bubble (auto or manual)
  int? _manualExpandedIndex; // Track user manual click
  int? _suppressedAutoIndex; // Prevent immediate auto re-expand after collapse
  bool _autoExpandDisabled = false; // Disable auto-expand until user drags
  double _mapRotation = 0.0; // 地图旋转角度（弧度）
  double _currentZoom = 17.0; // 当前缩放级别，默认为 17.0（两条街尺度，3D 建筑清晰）
  bool _isViewportReady = false; // 是否已拿到有效地图视口尺寸

  // Cache scale factors for each marker
  final Map<int, double> _scaleFactors = {};

  // 精确的真实屏幕坐标缓存（使用原生 Mapbox SDK 异步映射）
  // 键：`p_<postId>` 单点 / `c_<clusterId>` 聚合（= ClusterOrPoint.id）
  final Map<String, MapScreenPoint> _postScreenPoints = {};
  bool _isUpdatingPositions = false;
  bool _needsPositionUpdate = false; // 当更新被跳过时标记需要重试

  // —— 聚合相关 ——
  /// 聚合引擎（纯 Dart，地图库无关）
  final SuperclusterEngine _clusterEngine = SuperclusterEngine();

  /// 当前视口的聚合查询结果（cluster 与单点混合）
  ///
  /// 初始为空列表 → 用 `posts` 单点渲染作为回退；
  /// 首次 `_recomputeClusters` 后替换为真实结果。
  List<ClusterOrPoint> _clusterResults = const [];

  // 用户位置相关
  MapLatLng? _userLocation;
  bool _locationLoading = true;

  // 记录上次已经 SnackBar 过的错误信息，避免同一错误反复 toast
  String? _lastShownError;

  // 记录上一次 posts 的签名，用于检测 posts 刷新后重新计算屏幕坐标
  String _lastPostsSignature = '';

  // 滑动防抖计时器，用于在用户停止滑动后刷新 posts
  Timer? _cameraMoveDebounce;

  final GlobalKey _addButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _cameraMoveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationPermissionDialog('定位服务未开启，请在系统设置中开启定位服务。');
        _useFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationPermissionDialog('需要定位权限才能显示您附近的内容。请允许 Jogy 访问您的位置。');
          _useFallbackLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog('定位权限已被永久拒绝，请前往系统设置手动开启。');
        _useFallbackLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      setState(() {
        _userLocation = MapLatLng(position.latitude, position.longitude);
        _locationLoading = false;
      });

      // 根据用户位置获取附近的 posts
      if (mounted) {
        Provider.of<PostProvider>(context, listen: false).fetchPostsByLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (e) {
      print('获取位置失败: $e');
      _useFallbackLocation();
    }
  }

  /// GPS 不可用时，使用默认位置
  void _useFallbackLocation() {
    const defaultLat = 39.9042;
    const defaultLng = 116.4074;
    setState(() {
      _userLocation = MapLatLng(defaultLat, defaultLng);
      _locationLoading = false;
    });
    if (mounted) {
      Provider.of<PostProvider>(context, listen: false).fetchPostsByLocation(
        latitude: defaultLat,
        longitude: defaultLng,
      );
    }
  }

  /// 在 Consumer 监听到新的 error 时 toast 一次；error 清除后重置以便下次再提示。
  /// 在 build 的过程中不能直接 showSnackBar（那会触发 setState），
  /// 所以用 addPostFrameCallback 延迟到帧结束。
  void _maybeShowErrorSnackBar(String? error) {
    if (error == null) {
      _lastShownError = null;
      return;
    }
    if (error == _lastShownError) return;
    _lastShownError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载附近内容失败: $error'),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  /// 弹出定位权限提示对话框
  void _showLocationPermissionDialog(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要定位权限'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('暂不开启'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openAppSettings();
              },
              child: const Text('前往设置'),
            ),
          ],
        ),
      );
    });
  }

  // 计算”理想尖角位置”（用于自动展开判断和点击居中），只依赖屏幕尺寸，
  // 与底部导航栏等 UI 高度解耦，保证以后改导航栏不会影响气泡锚点。
  Offset _expandedBubbleTipTarget(MapScreenPoint viewportSize) {
    final screenCenterY = viewportSize.y / 2;
    // 向上偏移 1/3 屏幕高度
    final upwardOffset = viewportSize.y / 7;
    return Offset(
      viewportSize.x / 2,
      screenCenterY + _expandedBubbleTipYOffset - upwardOffset,
    );
  }

  Offset _expandedBubbleCenterOffset(MapScreenPoint viewportSize) {
    // 计算屏幕像素偏移，用于 adjustCenterForScreenOffset。
    final targetTip = _expandedBubbleTipTarget(viewportSize);
    final screenCenterY = viewportSize.y / 2;
    // 计算偏移：目标位置 - 屏幕中心
    return Offset(0, targetTip.dy - screenCenterY);
  }

  // Calculate scale factor based on distance from screen center
  void _updateScaleFactors() {
    try {
      final controller = _jogyMapController;
      if (controller == null) return;
      final state = controller.cameraState;
      final vw = state.viewportSize.x;
      final vh = state.viewportSize.y;
      if (vw == 0 || vh == 0) return;
      final viewportSize = state.viewportSize;

      final posts = context.read<PostProvider>().posts;

      // 自动展开的判定中心与点击居中的尖角目标一致，
      // 只依赖屏幕尺寸，不依赖底部导航栏高度。
      final focusPoint = _expandedBubbleTipTarget(viewportSize);
      final centerX = focusPoint.dx;
      final centerY = focusPoint.dy;

      final maxDistance = math.sqrt(vw * vw + vh * vh) / 2;
      bool needsRebuild = false;
      bool suppressedStillEligible = false;

      // Auto-expansion threshold: 30% of screen width (increased for easier triggering)
      final expansionThreshold = vw * 0.30;
      int? closestIndex;
      double minDistance = double.infinity;

      for (int i = 0; i < posts.length; i++) {
        final markerPosition = MapLatLng(
          posts[i].location.latitude,
          posts[i].location.longitude,
        );

        // Get marker's screen position (this is the bubble tip location)
        final markerPoint = controller.latLngToScreenPoint(markerPosition);
        if (markerPoint == null) continue;

        // Calculate distance from marker point to center
        // For auto-expand, we check if the marker enters the center zone
        final dx = markerPoint.x - centerX;
        final dy = markerPoint.y - centerY;
        final distance = math.sqrt(dx * dx + dy * dy);

        // Track closest bubble within threshold
        // 使用纯距离判断,不依赖 dy 带状检查,以支持地图旋转
        final isEligible = distance < expansionThreshold;
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
      if (_manualExpandedIndex == null && !_autoExpandDisabled) {
        if (closestIndex != _expandedIndex) {
          _expandedIndex = closestIndex;
          needsRebuild = true;
        }
      } else if (_manualExpandedIndex != null) {
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

  // 异步获取 Mapbox 引擎底层原生坐标（完美贴合 3D Pitch 和偏航）
  //
  // 计算对象：聚合结果（cluster + 单点）。聚合未就绪时回退到 posts 列表。
  // 位置缓存键：`ClusterOrPoint.id`（`p_<postId>` 或 `c_<clusterId>`）
  Future<void> _updatePostPositionsAsync() async {
    if (_jogyMapController == null) return;

    // 如果正在更新，标记需要重试，而不是直接丢弃
    if (_isUpdatingPositions) {
      _needsPositionUpdate = true;
      return;
    }

    // 优先使用 cluster 结果；未就绪时用 posts 单点作为回退
    final items = _currentRenderItems();
    if (items.isEmpty) return;

    _isUpdatingPositions = true;
    _needsPositionUpdate = false;
    try {
      final futures = items.map((item) async {
        final pt = await _jogyMapController!.latLngToScreenPointAsync(
          item.center,
        );
        return MapEntry(item.id, pt);
      });
      final entries = await Future.wait(futures);

      if (mounted) {
        bool needsUpdate = false;
        // 清理不再存在的 key（避免 stale cluster 残留）
        final activeIds = items.map((e) => e.id).toSet();
        _postScreenPoints.removeWhere((k, _) => !activeIds.contains(k));

        for (var entry in entries) {
          if (entry.value != null) {
            final old = _postScreenPoints[entry.key];
            if (old == null ||
                old.x != entry.value!.x ||
                old.y != entry.value!.y) {
              _postScreenPoints[entry.key] = entry.value!;
              needsUpdate = true;
            }
          }
        }
        if (needsUpdate) {
          setState(() {});
          _updateScaleFactors(); // Refresh scale when coords arrive
        }
      }
    } finally {
      _isUpdatingPositions = false;
      // 如果在更新期间有被跳过的请求，立即重试
      if (_needsPositionUpdate && mounted) {
        _needsPositionUpdate = false;
        _updatePostPositionsAsync();
      }
    }
  }

  /// 当前应渲染的条目列表：优先 cluster 结果，未就绪时 posts 全量单点
  List<ClusterOrPoint> _currentRenderItems() {
    if (_clusterResults.isNotEmpty) return _clusterResults;
    final posts = Provider.of<PostProvider>(context, listen: false).posts;
    return posts.map<ClusterOrPoint>(SinglePoint.new).toList();
  }

  Future<void> _navigateToSearch() async {
    final result = await Navigator.push<PostModel>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SearchPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, -1.0); // 从顶部滑入
          const end = Offset.zero;
          const curve = Curves.easeOut;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );

    if (result != null && mounted && _jogyMapController != null) {
      // 找到对应的 index
      final posts = context.read<PostProvider>().posts;
      final index = posts.indexWhere((p) => p.id == result.id);

      if (index != -1) {
        // 定位到该帖子
        setState(() {
          _manualExpandedIndex = index;
          _expandedIndex = index;
          _suppressedAutoIndex = null;
        });

        final viewportSize = _jogyMapController!.cameraState.viewportSize;
        final offset = _expandedBubbleCenterOffset(viewportSize);
        final target = MapLatLng(result.location.latitude, result.location.longitude);
        final adjustedCenter = MapGeoUtils.adjustCenterForScreenOffset(
          target, 16, offset.dx, offset.dy,
        );
        _jogyMapController!.moveTo(adjustedCenter, zoom: 16);
      }
    }
  }

  void _showAddMenu() {
    final RenderBox? renderBox =
        _addButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    // 菜单宽度
    const menuWidth = 140.0;
    // 菜单项高度

    // 菜单总高度 (2项) + padding

    // 计算菜单位置：按钮下方，右对齐
    final top = position.dy + size.height + 8;
    final right =
        MediaQuery.of(context).size.width - (position.dx + size.width);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: top,
              right: right,
              child: Material(
                color: Colors.transparent,
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  alignment: Alignment.topRight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: menuWidth,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(153), // 60% 不透明度
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMenuItem(
                              icon: Icons.qr_code_scanner,
                              label: '扫一扫',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ScanPage(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildMenuItem(
                              icon: Icons.qr_code,
                              label: '我的二维码',
                              onTap: () {
                                Navigator.pop(context);
                                _showQRCodeDialog(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  void _openMessagePage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const _MessageSheetContent(),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 地图相机移动回调
  void _onCameraMove(MapCameraEvent event) {
    if (!_isViewportReady &&
        event.camera.viewportSize.x > 0 &&
        event.camera.viewportSize.y > 0) {
      setState(() => _isViewportReady = true);
    }

    // Re-enable auto-expand on gesture
    if (event.source == MapMoveSource.gesture) {
      if (_manualExpandedIndex != null) {
        _manualExpandedIndex = null;
      }
      if (_autoExpandDisabled) {
        _autoExpandDisabled = false;
      }
    }

    // 更新地图旋转角度
    final newRotation = event.camera.bearing * (math.pi / 180);
    if (_mapRotation != newRotation) {
      _mapRotation = newRotation;
    }
    // Update current zoom
    if (_currentZoom != event.camera.zoom) {
      _currentZoom = event.camera.zoom;
    }
    // Update marker positions using the precise async coordinates approach
    _updatePostPositionsAsync();

    // 用户手势滑动时，防抖 500ms 后根据新视口刷新 posts
    if (event.source == MapMoveSource.gesture) {
      _cameraMoveDebounce?.cancel();
      _cameraMoveDebounce = Timer(const Duration(milliseconds: 500), () {
        _refreshPostsForCurrentViewport();
      });
    }
  }

  // 地图相机停止移动（手势/动画结束）—— 重算聚合
  void _onCameraIdle(MapCameraEvent event) {
    _recomputeClusters();
  }

  /// 根据当前 bounds + zoom 重新分簇
  ///
  /// 调用时机：
  /// - `onMapCreated` 后首次 viewport 就绪
  /// - 每次 `onCameraIdle`
  /// - PostProvider 的 posts 变化（data reload）后
  Future<void> _recomputeClusters() async {
    final controller = _jogyMapController;
    if (controller == null) return;

    final bounds = await controller.getVisibleBounds();
    if (bounds == null || !mounted) return;

    // 为避免视口边缘的点被遗漏，扩一圈 clusterRadiusPx 对应的经纬度
    final padDeg = controller.pixelDistanceToDegrees(
      _clusterEngine.config.clusterRadiusPx,
      bounds.center,
      controller.cameraState.zoom,
    );
    final paddedBounds = MapBounds(
      southwest: MapLatLng(
        bounds.minLatitude - padDeg,
        bounds.minLongitude - padDeg,
      ),
      northeast: MapLatLng(
        bounds.maxLatitude + padDeg,
        bounds.maxLongitude + padDeg,
      ),
    );

    final results = _clusterEngine.getClusters(
      bounds: paddedBounds,
      zoom: controller.cameraState.zoom,
    );

    if (!mounted) return;
    setState(() {
      _clusterResults = results;
    });
    // 聚合结果变化后重算屏幕坐标
    _updatePostPositionsAsync();
  }

  /// 根据当前地图视口刷新 posts
  Future<void> _refreshPostsForCurrentViewport() async {
    final controller = _jogyMapController;
    if (controller == null) return;

    final bounds = await controller.getVisibleBounds();
    if (bounds == null || !mounted) return;

    Provider.of<PostProvider>(context, listen: false).fetchPostsByBounds(
      minLatitude: bounds.minLatitude,
      minLongitude: bounds.minLongitude,
      maxLatitude: bounds.maxLatitude,
      maxLongitude: bounds.maxLongitude,
    );
  }

  // 地图点击回调
  void _onMapTap(MapLatLng latLng) {
    final collapsedIndex = _expandedIndex;
    setState(() {
      _manualExpandedIndex = null;
      _expandedIndex = null;
      _suppressedAutoIndex = collapsedIndex;
      _autoExpandDisabled = true;
    });
  }

  // 构建单点气泡覆盖层（兼容层：被新的 _buildItemOverlay 调用）
  Widget _buildBubbleOverlay(List<PostModel> posts, int index) {
    final post = posts[index];
    final isExpanded = _expandedIndex == index;
    final scaleFactor = _scaleFactors[index] ?? 1.0;

    // Use highly accurate asynchronously pre-fetched native Mapbox screen point
    final screenPoint = _postScreenPoints['p_${post.id}'];
    if (screenPoint == null) return const SizedBox.shrink();

    // Alignment: bottomCenter - 尖角在地理坐标位置
    const size = MapBubbleWidget.expandedHeight;
    return Positioned(
      left: screenPoint.x - size / 2,
      top: screenPoint.y - size,
      width: size,
      height: size,
      child: MapBubbleWidget(
        isExpanded: isExpanded,
        scaleFactor: scaleFactor,
        post: post,
        mapRotation: _mapRotation,
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
            BrowsingHistoryService().addToHistory(post);
            setState(() {
              _manualExpandedIndex = index;
              _expandedIndex = index;
              _suppressedAutoIndex = null;
            });
            if (_jogyMapController != null) {
              final viewportSize =
                  _jogyMapController!.cameraState.viewportSize;
              final offset = _expandedBubbleCenterOffset(viewportSize);
              final target = MapLatLng(
                post.location.latitude,
                post.location.longitude,
              );
              final adjustedCenter =
                  MapGeoUtils.adjustCenterForScreenOffset(
                target,
                16,
                offset.dx,
                offset.dy,
              );
              _jogyMapController!.moveTo(adjustedCenter, zoom: 16);
            }
          }
        },
      ),
    );
  }

  /// 构建聚合/单点覆盖层（cluster-aware）
  Widget _buildItemOverlay(ClusterOrPoint item, List<PostModel> posts) {
    if (item is SinglePoint) {
      // 找到 item.post 在 posts 列表中的 index，沿用原有的自动展开/scale 体系
      final idx = posts.indexWhere((p) => p.id == item.post.id);
      if (idx < 0) return const SizedBox.shrink();
      return _buildBubbleOverlay(posts, idx);
    }

    // ClusterNode 分支
    final cluster = item as ClusterNode;
    final screenPoint = _postScreenPoints[cluster.id];
    if (screenPoint == null) return const SizedBox.shrink();

    // Cluster 不展开，但 scale 仍随距离变化。用 cluster.id 作为 key 让手势期间
    // 的 scale 过渡与单点一致——先简单统一用 1.0，后续若需要可扩展 _updateScaleFactors。
    const size = MapBubbleWidget.expandedHeight;
    return Positioned(
      key: ValueKey(cluster.id),
      left: screenPoint.x - size / 2,
      top: screenPoint.y - size,
      width: size,
      height: size,
      child: RepaintBoundary(
        child: MapBubbleWidget(
          isExpanded: false,
          scaleFactor: 1.0,
          cluster: cluster,
          mapRotation: _mapRotation,
          onTap: () => _onClusterTap(cluster),
        ),
      ),
    );
  }

  /// 点击聚合：smart zoom 到可以展开此 cluster 的最小 zoom
  void _onClusterTap(ClusterNode cluster) {
    final controller = _jogyMapController;
    if (controller == null) return;
    final targetZoom = _clusterEngine
        .getClusterExpansionZoom(cluster)
        .clamp(0.0, 20.0);
    controller.moveTo(
      cluster.center,
      zoom: targetZoom,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostProvider>(
      builder: (context, postProvider, child) {
        // 错误用 SnackBar 提示一次，不阻塞整个页面；地图与工具栏始终渲染
        _maybeShowErrorSnackBar(postProvider.error);

        final posts = postProvider.posts;

        // Initialize scale factors if not already done
        if (_scaleFactors.isEmpty && posts.isNotEmpty) {
          for (int i = 0; i < posts.length; i++) {
            _scaleFactors[i] = 1.0;
          }
        }

        // posts 为空时：可能是首次加载尚未完成，显示地图（不显示 "No posts found"）
        // 地图会在 posts 到达后通过 Consumer rebuild 自动显示气泡

        // Posts 刷新后（坐标变化），重建聚合索引 + 重新计算屏幕坐标
        final postsSignature = posts.isEmpty
            ? ''
            : '${posts.length}_${posts[0].location.latitude}_${posts[0].location.longitude}';
        if (_lastPostsSignature != postsSignature) {
          _lastPostsSignature = postsSignature;
          // 先重建聚合索引（同步、O(n log n)，通常 <20ms）
          _clusterEngine.load(posts);
          // 帧结束后触发，避免在 build 中调用 setState
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _jogyMapController != null) {
              _postScreenPoints.clear();
              // 重算聚合（会间接触发 _updatePostPositionsAsync）
              _recomputeClusters();
            }
          });
        }

        // 聚合/单点混合渲染列表。展开态的单点排最后（渲染在最上）
        final renderItems =
            _clusterResults.isNotEmpty
                ? List<ClusterOrPoint>.from(_clusterResults)
                : posts.map<ClusterOrPoint>(SinglePoint.new).toList();
        if (_expandedIndex != null && _expandedIndex! < posts.length) {
          final expandedPostId = posts[_expandedIndex!].id;
          renderItems.sort((a, b) {
            final aIsExpanded =
                a is SinglePoint && a.post.id == expandedPostId;
            final bIsExpanded =
                b is SinglePoint && b.post.id == expandedPostId;
            if (aIsExpanded && !bIsExpanded) return 1;
            if (!aIsExpanded && bIsExpanded) return -1;
            return 0;
          });
        }

        // 使用用户位置作为中心，如果获取失败则使用第一个 post 位置或 fallback
        final mapCenter = _userLocation ??
            (posts.isNotEmpty
                ? MapLatLng(posts[0].location.latitude, posts[0].location.longitude)
                : const MapLatLng(39.9042, 116.4074));

        return Stack(
          children: [
            // 基础地图 Widget（由 Mapbox 适配器构建）
            MapboxMapWidgetBuilder(
              styleUri: MapConfig.mapboxStyleUri,
            ).build(JogyMapOptions(
              initialCenter: mapCenter,
              initialZoom: 17.0,
              initialPitch: 45.0,
              onMapCreated: (controller) {
                setState(() {
                  _jogyMapController = controller;
                  _isViewportReady =
                      controller.cameraState.viewportSize.x > 0 &&
                      controller.cameraState.viewportSize.y > 0;
                });
                // 初次拉取到 posts 时已经 load，这里补一次以防 onMapCreated 晚于数据
                if (posts.isNotEmpty) {
                  _clusterEngine.load(posts);
                }
                // Initialize bubble positions + 首次聚合计算
                _recomputeClusters();
              },
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
              onTap: _onMapTap,
            )),
            // 标记覆盖层（仅在地图控制器就绪后渲染）
            // 用户位置由 Mapbox 原生 location puck 显示，无需 Flutter overlay
            if (_jogyMapController != null && _isViewportReady) ...[
              // Posts / Cluster 气泡标记
              ...renderItems.map((item) => _buildItemOverlay(item, posts)),
            ],
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
                      onTap: _navigateToSearch,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(240),
                            borderRadius: BorderRadius.circular(25),
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
                  const SizedBox(width: 10),
                  // 消息按钮
                  GestureDetector(
                    onTap: _openMessagePage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(240),
                          borderRadius: BorderRadius.circular(22),
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
                  const SizedBox(width: 10),
                  // 发布按钮
                  GestureDetector(
                    key: _addButtonKey,
                    onTap: _showAddMenu,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(240),
                          borderRadius: BorderRadius.circular(22),
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
                ],
              ),
            ),
            // 定位按钮：回到当前位置 + 恢复朝向跟随
            Positioned(
              right: 16,
              bottom: 150,
              child: LocationButton(
                onTap: () {
                  // 重新进入 FollowPuck 模式（跟随位置 + 朝向旋转）
                  _jogyMapController?.followUserWithHeading(zoom: 17);
                },
              ),
            ),
            // 小型 loading 徽标：定位中或首次 posts 加载中，右上角显示
            // 放在最后以保证在工具栏之上
            if (_locationLoading ||
                (postProvider.isLoading && postProvider.posts.isEmpty))
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                right: 24,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showQRCodeDialog(BuildContext context) {
    final GlobalKey qrKey = GlobalKey();

    // 先显示 loading，异步获取真实用户数据
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FutureBuilder(
          future: RemoteDataSource().getCurrentUser(),
          builder: (context, snapshot) {
            // 获取到用户数据或失败后都显示 dialog
            final username = snapshot.data?.username ?? 'Jogy User';
            final avatarUrl = snapshot.data?.avatarUrl ?? '';
            final userId = snapshot.data?.id ?? '';
            final qrData = userId.isNotEmpty
                ? 'jogy://user/profile/$userId'
                : 'jogy://user/profile/unknown';
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      )
                    else ...[
                      RepaintBoundary(
                        key: qrKey,
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl.isEmpty
                                    ? const Icon(Icons.person, size: 40)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                username,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '扫码查看主页',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 200.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('关闭'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _saveQRCodeToGallery(qrKey),
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('保存图片'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3FAAF0),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveQRCodeToGallery(GlobalKey key) async {
    try {
      // 1. Request Permission
      // For Android 10+ (API 29+), storage permission is not explicitly needed for saving public images,
      // but standard approach typically checks photos/storage.
      // For simple implementation we try direct save, catch error if permission needed.
      // However, permission_handler is good practice.
      /*
      if (Platform.isAndroid) {
         // Check android version logic if needed, or just rely on image_gallery_saver to handle
      } else {
         var status = await Permission.photosAddOnly.request();
         if (!status.isGranted) {
           throw Exception('Permission denied');
         }
      }
      */

      // 2. Capture Image
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Increase pixel ratio for better quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // 3. Save to Gallery
      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: "jogy_qr_code_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (result['isSuccess'] == true) {
        if (mounted) {
          Navigator.pop(context); // Optional: close dialog on success
        }
      } else {
        throw Exception('Save failed: ${result['errorMessage']}');
      }
    } catch (e) {
      // Intentionally no system prompt for a cleaner UI.
    }
  }

  // Mapbox 原生 flyTo 已自带动画，无需手动 Tween
}

// 消息发布界面内容
class _MessageSheetContent extends StatefulWidget {
  const _MessageSheetContent();

  @override
  State<_MessageSheetContent> createState() => _MessageSheetContentState();
}

class _MessageSheetContentState extends State<_MessageSheetContent> {
  bool _isImageMode = true; // true = 图片模式, false = 文字模式
  String _selectedDuration = '永久'; // 留存时长
  final GlobalKey _durationChipKey = GlobalKey(); // popover anchor

  // Post publish state
  final List<File> _selectedPostImages = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // Location state
  LocationModel? _currentLocation;
  bool _isLocationLoading = true;
  bool _hasManualLocation = false;

  // Publish state
  bool _isPublishing = false;

  Future<void> _pickPostImage() async {
    try {
      final List<XFile> images = await ImagePicker().pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedPostImages.addAll(images.map((img) => File(img.path)));
        });
      }
    } catch (e) {
      debugPrint('Error picking post image: $e');
    }
  }

  void _removePostImage(int index) {
    setState(() {
      _selectedPostImages.removeAt(index);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      // 获取当前位置
      final currentPos = await Geolocator.getCurrentPosition();

      if (!mounted) return;
      if (_hasManualLocation) {
        if (_isLocationLoading) {
          setState(() => _isLocationLoading = false);
        }
        return;
      }

      // 逆地理编码：Mapbox Geocoding v5
      String placeName = '当前位置';
      String address = '';
      try {
        final geo = await Dio().get(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/'
          '${currentPos.longitude},${currentPos.latitude}.json',
          queryParameters: {
            'access_token': MapConfig.mapboxApiKey,
            'language': mapboxLanguage(),
            'limit': 1,
          },
        );
        final features = geo.data['features'] as List? ?? [];
        if (features.isNotEmpty) {
          final f = features.first;
          placeName = f['text'] as String? ?? '当前位置';
          final fullName = f['place_name'] as String? ?? '';
          if (fullName.startsWith(placeName) &&
              fullName.length > placeName.length) {
            address = fullName
                .substring(placeName.length)
                .replaceFirst(RegExp(r'^,\s*'), '');
          } else {
            address = fullName;
          }
        }
      } catch (_) {
        // 逆地理编码失败时使用默认值
      }

      setState(() {
        _currentLocation = LocationModel(
          latitude: currentPos.latitude,
          longitude: currentPos.longitude,
          placeName: placeName,
          address: address,
        );
        _isLocationLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  Future<void> _pickLocation() async {
    if (_currentLocation == null) return;

    final result = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLat: _currentLocation!.latitude,
          initialLng: _currentLocation!.longitude,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentLocation = result;
        _hasManualLocation = true;
      });
    }
  }

  /// Convert duration label to an ISO 8601 expire timestamp (or null for permanent)
  String? _durationToExpireAt(String duration) {
    final now = DateTime.now();
    switch (duration) {
      case '30分钟':
        return now.add(const Duration(minutes: 30)).toUtc().toIso8601String();
      case '1个小时':
        return now.add(const Duration(hours: 1)).toUtc().toIso8601String();
      case '10小时':
        return now.add(const Duration(hours: 10)).toUtc().toIso8601String();
      case '1天':
        return now.add(const Duration(days: 1)).toUtc().toIso8601String();
      default:
        return null; // 永久
    }
  }

  Future<void> _handlePublish() async {
    // Validate
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入内容')),
      );
      return;
    }
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在获取位置，请稍候')),
      );
      return;
    }

    debugPrint(
      '[_handlePublish] start, images=${_selectedPostImages.length}',
    );
    setState(() => _isPublishing = true);

    try {
      final remote = RemoteDataSource();

      // 1. Upload images in parallel
      debugPrint('[_handlePublish] uploading images...');
      List<String> mediaUrls = [];
      if (_selectedPostImages.isNotEmpty) {
        final uploadFutures = _selectedPostImages
            .map((file) => remote.uploadImage(file.path))
            .toList();
        mediaUrls = await Future.wait(uploadFutures);
      }
      debugPrint('[_handlePublish] images uploaded: $mediaUrls');

      // 2. Create the post
      final postType = _isImageMode ? 'bubble' : 'broadcast';
      final title = _titleController.text.trim();
      final expireAt = _durationToExpireAt(_selectedDuration);

      debugPrint('[_handlePublish] calling createPost...');
      final newPost = await remote.createPost(
        contentText: content,
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        postType: postType,
        title: title.isNotEmpty ? title : null,
        addressName: _currentLocation!.placeName ?? _currentLocation!.address,
        mediaUrls: mediaUrls.isNotEmpty ? mediaUrls : null,
        expireAt: expireAt,
      );
      debugPrint('[_handlePublish] createPost OK, id=${newPost.id}');

      // 3. Delete draft — 非关键路径，失败不影响发布成功反馈
      try {
        await _deleteDraft();
      } catch (e) {
        debugPrint('[_handlePublish] Delete draft failed: $e');
      }

      if (!mounted) return;

      // 4. Add to PostProvider — 非关键路径，rebuild 失败不应影响发布成功反馈
      try {
        context.read<PostProvider>().addNewPost(newPost);
      } catch (e, st) {
        debugPrint('[_handlePublish] addNewPost failed: $e\n$st');
      }

      // 5. 关闭发布 sheet，清掉可能排队中的旧 SnackBar（"请输入内容"/"正在获取位置"），
      //    然后在屏幕正中央短暂展示成功 toast（OverlayEntry，不依赖 sheet 上下文）。
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      // 复位发布状态（下次再打开 sheet 按钮是干净状态，而非残留 spinner）
      if (mounted) {
        setState(() => _isPublishing = false);
      }

      messenger.hideCurrentSnackBar();
      if (mounted) {
        showCenterToast(context, message: '发布成功');
      }
      debugPrint('[_handlePublish] done');
    } catch (e, st) {
      debugPrint('[_handlePublish] FAILED: $e\n$st');
      if (!mounted) return;
      setState(() => _isPublishing = false);

      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败：$msg')),
      );
    }
  }

  Future<void> _loadDraft() async {
    // 包 try/catch：草稿读取失败（如本地 DB 损坏）时降级为空白，不应阻塞 sheet 打开
    try {
      final draft = await DatabaseHelper().getDraft();
      if (draft != null && mounted) {
        setState(() {
          if (draft['title'] != null) {
            _titleController.text = draft['title'];
          }
          if (draft['content'] != null) {
            _contentController.text = draft['content'];
          }
          if (draft['image_paths'] != null) {
            try {
              List<dynamic> paths = jsonDecode(draft['image_paths']);
              _selectedPostImages.addAll(
                paths.map((e) => File(e.toString())),
              );
            } catch (e) {
              debugPrint('Error parsing draft images: $e');
            }
          }
          // Restore type if needed, or default
          if (draft['type'] == 'broadcast') {
            _isImageMode = false;
          } else {
            _isImageMode = true;
          }

          // Restore location
          if (draft['location_lat'] != null &&
              draft['location_lng'] != null) {
            _currentLocation = LocationModel(
              latitude: draft['location_lat'],
              longitude: draft['location_lng'],
              placeName: draft['location_place_name'],
              address: draft['location_address'],
            );
            _hasManualLocation = true;
            _isLocationLoading = false; // Override auto-location loading
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  Future<void> _saveDraft() async {
    List<String> imagePaths = _selectedPostImages.map((e) => e.path).toList();
    await DatabaseHelper().saveDraft({
      'title': _titleController.text,
      'content': _contentController.text,
      'image_paths': jsonEncode(imagePaths),
      'type': _isImageMode ? 'bubble' : 'broadcast',
      'location_lat': _currentLocation?.latitude,
      'location_lng': _currentLocation?.longitude,
      'location_place_name': _currentLocation?.placeName,
      'location_address': _currentLocation?.address,
    });
  }

  Future<void> _deleteDraft() async {
    await DatabaseHelper().deleteDraft();
  }

  Future<void> _onCloseTap() async {
    // Check if dirty
    bool isDirty =
        _titleController.text.isNotEmpty ||
        _contentController.text.isNotEmpty ||
        _selectedPostImages.isNotEmpty;

    if (!isDirty) {
      Navigator.pop(context);
      return;
    }

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存草稿？'),
        content: const Text('保存后，下次打开将自动恢复输入内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('不保存', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存', style: TextStyle(color: Color(0xFF3FAAF0))),
          ),
        ],
      ),
    );

    if (shouldSave == null) return; // Dismissed

    bool saveOk = true;
    String? saveErrMsg;
    if (shouldSave) {
      try {
        await _saveDraft();
      } catch (e) {
        saveOk = false;
        saveErrMsg = e.toString();
        debugPrint('Error saving draft: $e');
      }
    } else {
      try {
        await _deleteDraft();
      } catch (e) {
        debugPrint('Error deleting draft: $e');
      }
    }

    if (!mounted) return;

    // 先捕获 messenger 再 pop，否则 pop 后 context 可能失效
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    if (shouldSave) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(saveOk ? '草稿已保存' : '草稿保存失败：$saveErrMsg'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static const List<String> _durationOptions = [
    '30分钟',
    '1个小时',
    '10小时',
    '1天',
    '永久',
  ];

  // Toggle button width for animation calculation
  static const double _toggleButtonWidth = 60.0;
  static const double _toggleButtonHeight = 36.0;
  static const double _toggleButtonPadding = 4.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: X button + 图片/文字 toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Close button (left)
              GestureDetector(
                onTap: _onCloseTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
              // Segmented control (图片/文字) - centered with bubble flow animation
              Expanded(
                child: Center(
                  child: Container(
                    height: _toggleButtonHeight + _toggleButtonPadding * 2,
                    width: _toggleButtonWidth * 2 + _toggleButtonPadding * 2,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.all(_toggleButtonPadding),
                    child: Stack(
                      children: [
                        // Animated bubble indicator
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          left: _isImageMode ? 0 : _toggleButtonWidth,
                          top: 0,
                          bottom: 0,
                          width: _toggleButtonWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(20),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Toggle buttons row
                        Row(
                          children: [
                            _buildToggleItem('气泡', true),
                            _buildToggleItem('广播', false),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Publish button (right)
              GestureDetector(
                onTap: _isPublishing ? null : _handlePublish,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isPublishing
                        ? const Color(0xFF3FAAF0).withAlpha(128)
                        : const Color(0xFF3FAAF0),
                    shape: BoxShape.circle,
                  ),
                  child: _isPublishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward,
                          size: 20,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ),
        // Content area
        // Content area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image picker (only when 图片 mode)
                  // Image picker (only when 图片 mode)
                  if (_isImageMode) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._selectedPostImages.asMap().entries.map((entry) {
                            final index = entry.key;
                            final file = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removePostImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: _pickPostImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Icon(
                                Icons.add,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title Input (Only in Bubble mode)
                    TextField(
                      controller: _titleController,
                      maxLength: 20,
                      decoration: InputDecoration(
                        hintText: '加个标题...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        counterText: "", // Hide counter
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Text input
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: _isImageMode ? '写点什么...' : '发布广播...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),

                  // Location Bubble (New)
                  if (!_isLocationLoading)
                    GestureDetector(
                      onTap: _pickLocation,
                      child: Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Color(0xFF3FAAF0),
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                _currentLocation?.placeName ?? '点击选择位置',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Retention duration selector (only in text mode)
                  if (!_isImageMode) ...[
                    const SizedBox(height: 24),
                    // Glass bubble label - tappable
                    GestureDetector(
                      onTap: () {
                        showWheelPopover(
                          context: context,
                          anchorKey: _durationChipKey,
                          options: _durationOptions,
                          selected: _selectedDuration,
                          onChanged: (value) {
                            setState(() => _selectedDuration = value);
                          },
                        );
                      },
                      child: ClipRRect(
                        key: _durationChipKey,
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(153),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(20),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '留存时长',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedDuration,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3FAAF0),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleItem(String label, bool isImageModeValue) {
    return SizedBox(
      width: _toggleButtonWidth,
      height: _toggleButtonHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _isImageMode = isImageModeValue);
        },
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: (_isImageMode == isImageModeValue)
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
