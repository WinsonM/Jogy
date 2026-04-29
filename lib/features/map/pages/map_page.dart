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
import '../../../core/services/auth_service.dart';
import '../widgets/gesture_passthrough_stack.dart';
import '../widgets/map_bubble.dart';
import '../widgets/post_bubbles_overlay.dart';
import '../widgets/zoom_arc_control.dart';
import '../clustering/cluster_engine.dart';
import '../clustering/cluster_models.dart';
import '../../detail/pages/detail_page.dart';
import '../../../presentation/providers/post_provider.dart';
import '../../../config/map_config.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../../utils/mapbox_language.dart';
import 'package:dio/dio.dart';
import 'search_page.dart';
import '../../scan/pages/scan_page.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../profile/services/browsing_history_service.dart';
import '../../scan/services/jogy_qr_codec.dart';
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

  /// 最近发布的 post 的强制 pin。
  ///
  /// 渲染时即使 [_clusterResults] 没包含它（discover 还没返回 / supercluster 边界
  /// 没覆盖 / 评分 / 过期 filter 等任意一环吞掉），也会在 build 末尾强制 append
  /// 一个 `SinglePoint(_pinnedPost!)` 到 renderItems。
  ///
  /// 自动清空时机（同一次 setState 里）：
  ///  - [_recomputeClusters] 的最新结果包含这条 post id（远端数据生效，pin 不再必要）；
  ///  - 已超过 [_pinnedPostTtl]（防止 post 被删/审核拒/永远不再返回时变成会话内幽灵）。
  PostModel? _pinnedPost;
  DateTime? _pinnedPostAt;

  /// pinned post 的最长保留时长。与 `PostProvider._localAdditionTtl` 对齐。
  static const Duration _pinnedPostTtl = Duration(minutes: 2);

  // 用户位置相关
  MapLatLng? _userLocation;
  bool _locationLoading = true;
  MapPlaceSearchResult? _selectedSearchPlace;
  PostModel? _replyingBroadcast;
  final TextEditingController _broadcastReplyController =
      TextEditingController();
  final FocusNode _broadcastReplyFocusNode = FocusNode();
  bool _isSendingBroadcastReply = false;

  // 记录上次已经 SnackBar 过的错误信息，避免同一错误反复 toast
  String? _lastShownError;

  // 记录上一次 posts 的签名，用于检测 posts 刷新后重新计算屏幕坐标
  String _lastPostsSignature = '';

  // 滑动防抖计时器，用于在用户停止滑动后刷新 posts
  Timer? _cameraMoveDebounce;

  /// 相机变化滴答。每次 [_onCameraMove] 触发时 +1，[PostBubblesOverlay] 监听
  /// 它来重算所有 post 的同步屏幕坐标。
  ///
  /// 用 [ValueNotifier] 而非直接 setState：避免每次相机移动都让整个 MapPage
  /// build 重跑（地图 widget / 工具栏 / 头像等都会重建一次），只让 overlay
  /// 这一层 setState。
  final ValueNotifier<int> _cameraTick = ValueNotifier(0);

  final GlobalKey _addButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _cameraMoveDebounce?.cancel();
    _cameraTick.dispose();
    _broadcastReplyController.dispose();
    _broadcastReplyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationPermissionDialog('定位服务未开启，请在系统设置中开启定位服务。');
        await _useFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationPermissionDialog('需要定位权限才能显示您附近的内容。请允许 Jogy 访问您的位置。');
          await _useFallbackLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog('定位权限已被永久拒绝，请前往系统设置手动开启。');
        await _useFallbackLocation();
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
      debugPrint('获取位置失败: $e');
      await _useFallbackLocation();
    }
  }

  /// GPS 不可用时，优先使用系统缓存位置；没有缓存再使用默认位置。
  Future<void> _useFallbackLocation() async {
    const defaultLat = 39.9042;
    const defaultLng = 116.4074;
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
    } catch (_) {
      // Permission/service failures fall back to the static default below.
    }
    if (!mounted) return;

    final latitude = lastKnown?.latitude ?? defaultLat;
    final longitude = lastKnown?.longitude ?? defaultLng;
    debugPrint(
      '[MapPage] using fallback location '
      'source=${lastKnown == null ? "default" : "last-known"} '
      'lat=$latitude lng=$longitude',
    );

    setState(() {
      _userLocation = MapLatLng(latitude, longitude);
      _locationLoading = false;
    });
    if (mounted) {
      Provider.of<PostProvider>(
        context,
        listen: false,
      ).fetchPostsByLocation(latitude: latitude, longitude: longitude);
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

  // 屏幕几何中心：同时作为自动展开判定锚点和点击 bubble 后的尖角目标。
  // 这与进入主页时本机定位点所在的视觉中心对齐，不再把触发区放到屏幕上方。
  Offset _expandedBubbleTipTarget(MapScreenPoint viewportSize) {
    return Offset(viewportSize.x / 2, viewportSize.y / 2);
  }

  Offset _expandedBubbleCenterOffset(MapScreenPoint viewportSize) {
    // 计算屏幕像素偏移，用于 adjustCenterForScreenOffset。
    final targetTip = _expandedBubbleTipTarget(viewportSize);
    final screenCenterY = viewportSize.y / 2;
    // 计算偏移：目标位置 - 屏幕中心
    return Offset(0, targetTip.dy - screenCenterY);
  }

  // 自动展开选择最靠近屏幕中心的 bubble；所有 bubble 保持固定尺寸。
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

      bool needsRebuild = false;
      bool suppressedStillEligible = false;

      // Auto-expansion threshold: 30% of screen width (increased for easier triggering)
      final expansionThreshold = vw * 0.30;
      int? closestIndex;
      double minDistance = double.infinity;

      for (int i = 0; i < posts.length; i++) {
        if (posts[i].isBroadcast) {
          if ((_scaleFactors[i] ?? 1.0) != 1.0) {
            needsRebuild = true;
          }
          _scaleFactors[i] = 1.0;
          continue;
        }

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

        // 所有未展开 bubble 同一固定尺寸，不再随距 focus 距离衰减。
        // 老的 0.3→1.0 放射衰减会让不同屏幕位置的 bubble 大小和
        // 主体到尖角的视觉距离不一致。
        if ((_scaleFactors[i] ?? 1.0) != 1.0) {
          needsRebuild = true;
        }
        _scaleFactors[i] = 1.0;
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
    final result = await Navigator.push<Object?>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SearchPage(proximity: _jogyMapController?.cameraState.center),
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

    if (!mounted || _jogyMapController == null) return;

    if (result is PostModel) {
      await _focusSearchPost(result);
    } else if (result is MapPlaceSearchResult) {
      await _focusSearchPlace(result);
    }
  }

  Future<void> _focusSearchPost(PostModel post) async {
    final controller = _jogyMapController;
    if (controller == null) return;

    // 找到对应的 index
    final posts = context.read<PostProvider>().posts;
    final index = posts.indexWhere((p) => p.id == post.id);

    setState(() {
      if (index != -1) {
        _manualExpandedIndex = index;
        _expandedIndex = index;
      } else {
        _manualExpandedIndex = null;
        _expandedIndex = null;
        _pinnedPost = post;
        _pinnedPostAt = DateTime.now();
      }
      _suppressedAutoIndex = null;
      _autoExpandDisabled = false;
      _clusterResults = const [];
      _postScreenPoints.clear();
      _selectedSearchPlace = null;
    });

    const targetZoom = 16.0;
    final viewportSize = controller.cameraState.viewportSize;
    final offset = _expandedBubbleCenterOffset(viewportSize);
    final target = MapLatLng(post.location.latitude, post.location.longitude);
    final adjustedCenter = MapGeoUtils.adjustCenterForScreenOffset(
      target,
      targetZoom,
      offset.dx,
      offset.dy,
    );

    await controller.moveTo(adjustedCenter, zoom: targetZoom);
    if (!mounted) return;
    _clusterEngine.load(context.read<PostProvider>().posts);
    await _refreshPostsForCurrentViewport();
    await _recomputeClusters();
  }

  Future<void> _focusSearchPlace(MapPlaceSearchResult place) async {
    final controller = _jogyMapController;
    if (controller == null) return;

    setState(() {
      _manualExpandedIndex = null;
      _expandedIndex = null;
      _suppressedAutoIndex = null;
      _autoExpandDisabled = false;
      _clusterResults = const [];
      _postScreenPoints.clear();
      _selectedSearchPlace = place;
    });

    await controller.moveTo(
      place.coordinate,
      zoom: 16,
      duration: Duration.zero,
    );
    if (!mounted) return;
    _cameraTick.value++;
    await _refreshPostsForCurrentViewport();
    await _recomputeClusters();
  }

  Widget _buildSearchPlaceMarker(MapPlaceSearchResult place) {
    final controller = _jogyMapController;
    if (controller == null) return const SizedBox.shrink();

    return ValueListenableBuilder<int>(
      valueListenable: _cameraTick,
      builder: (context, _, _) {
        final pt = controller.latLngToScreenPoint(place.coordinate);
        if (pt == null) return const SizedBox.shrink();

        return Positioned(
          left: pt.x - 88,
          top: pt.y - 72,
          width: 176,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 176),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(242),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(28),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.location_pin,
                  color: Color(0xFFE84D4D),
                  size: 34,
                ),
              ],
            ),
          ),
        );
      },
    );
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

  Future<void> _openMessagePage() async {
    final newPost = await showModalBottomSheet<PostModel>(
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
    if (!mounted || newPost == null) return;

    debugPrint(
      '[MapPage] publish returned id=${newPost.id}, '
      'location=${newPost.location.latitude},${newPost.location.longitude}',
    );

    _cameraMoveDebounce?.cancel();
    _cameraMoveDebounce = null;

    context.read<PostProvider>().addNewPost(newPost);
    // Pin 这条 post：build 时即使 _clusterResults / supercluster / 过期 filter 都
    // 没包含它，也强制注入一个 SinglePoint(pinned)；详见 _pinnedPost 文档。
    setState(() {
      _pinnedPost = newPost;
      _pinnedPostAt = DateTime.now();
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    showCenterToast(context, message: '发布成功');

    await _focusPublishedPost(newPost);
  }

  Future<void> _focusPublishedPost(PostModel post) async {
    final posts = context.read<PostProvider>().posts;
    final index = posts.indexWhere((p) => p.id == post.id);

    if (mounted) {
      setState(() {
        if (index >= 0 && post.isPhotoBubble) {
          _manualExpandedIndex = index;
          _expandedIndex = index;
        } else {
          _manualExpandedIndex = null;
          _expandedIndex = null;
        }
        _suppressedAutoIndex = null;
        _autoExpandDisabled = false;
        _clusterResults = const [];
        _postScreenPoints.clear();
      });
    }

    final controller = _jogyMapController;
    if (controller == null) return;

    const targetZoom = 17.0;
    final viewportSize = controller.cameraState.viewportSize;
    final offset = post.isPhotoBubble
        ? _expandedBubbleCenterOffset(viewportSize)
        : Offset.zero;
    final target = MapLatLng(post.location.latitude, post.location.longitude);
    final adjustedCenter = MapGeoUtils.adjustCenterForScreenOffset(
      target,
      targetZoom,
      offset.dx,
      offset.dy,
    );

    await controller.moveTo(
      adjustedCenter,
      zoom: targetZoom,
      duration: const Duration(milliseconds: 500),
    );
    if (mounted) {
      _cameraTick.value++;
    }

    if (!mounted) return;
    // 旧视口的 in-flight bounds fetch 可能刚好在发布和 moveTo 之间返回，并因
    // scope 过滤把这个 pending post 暂时排除出 _posts。moveTo 完成后再 upsert
    // 一次，确保接下来的聚合重算一定能看到刚发布的 post。
    context.read<PostProvider>().addNewPost(post);
    _clusterEngine.load(context.read<PostProvider>().posts);
    await _recomputeClusters();
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

  /// 处理气泡点击：collapsed → 展开 + 移动相机；expanded → 进详情页。
  /// 抽出来给 [PostBubblesOverlay] 复用，不再依赖 _buildBubbleOverlay 内部闭包。
  void _handleBubbleTap(PostModel post, int index) {
    final isExpanded = _expandedIndex == index;
    if (isExpanded) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => DetailPage(postId: post.id)),
      );
      return;
    }

    BrowsingHistoryService().addToHistory(post);
    setState(() {
      _manualExpandedIndex = index;
      _expandedIndex = index;
      _suppressedAutoIndex = null;
    });
    final controller = _jogyMapController;
    if (controller != null) {
      final viewportSize = controller.cameraState.viewportSize;
      final offset = _expandedBubbleCenterOffset(viewportSize);
      final target = MapLatLng(post.location.latitude, post.location.longitude);
      final adjustedCenter = MapGeoUtils.adjustCenterForScreenOffset(
        target,
        16,
        offset.dx,
        offset.dy,
      );
      unawaited(
        controller
            .moveTo(adjustedCenter, zoom: 16)
            .then((_) {
              if (mounted) {
                _cameraTick.value++;
              }
            })
            .catchError((Object e, StackTrace st) {
              debugPrint('[MapPage] bubble moveTo failed: $e\n$st');
            }),
      );
    }
  }

  void _handleBroadcastLike(PostModel post) {
    context.read<PostProvider>().toggleLike(post.id);
  }

  void _startBroadcastReply(PostModel post) {
    setState(() {
      _replyingBroadcast = post;
      _broadcastReplyController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _broadcastReplyFocusNode.requestFocus();
    });
  }

  void _cancelBroadcastReply() {
    setState(() {
      _replyingBroadcast = null;
      _broadcastReplyController.clear();
    });
    _broadcastReplyFocusNode.unfocus();
  }

  Future<void> _submitBroadcastReply() async {
    final target = _replyingBroadcast;
    final content = _broadcastReplyController.text.trim();
    if (target == null || content.isEmpty || _isSendingBroadcastReply) return;

    setState(() => _isSendingBroadcastReply = true);
    final comment = await context.read<PostProvider>().createComment(
      target.id,
      content: content,
      replyToUserId: target.user.id,
    );
    if (!mounted) return;

    setState(() => _isSendingBroadcastReply = false);
    if (comment == null) {
      showCenterToast(context, message: '回复失败');
      return;
    }

    _cancelBroadcastReply();
    showCenterToast(context, message: '已回复');
  }

  Widget _buildBroadcastReplyComposer() {
    final target = _replyingBroadcast;
    if (target == null) return const SizedBox.shrink();

    final bottom = MediaQuery.of(context).viewInsets.bottom + 92;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(235),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black.withAlpha(18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(24),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '取消',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _cancelBroadcastReply,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _broadcastReplyController,
                      focusNode: _broadcastReplyFocusNode,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitBroadcastReply(),
                      decoration: InputDecoration(
                        hintText: '回复 ${target.user.username}',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: '发送',
                    visualDensity: VisualDensity.compact,
                    icon: _isSendingBroadcastReply
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    onPressed: _isSendingBroadcastReply
                        ? null
                        : _submitBroadcastReply,
                  ),
                ],
              ),
            ),
          ),
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

    // Notify PostBubblesOverlay 重算同步屏幕坐标。比 setState 这层 MapPage 更
    // 轻量 —— 只让 overlay 这一层 build。
    _cameraTick.value++;

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

    final zoom = controller.cameraState.zoom;
    final results = _clusterEngine.getClusters(
      bounds: paddedBounds,
      zoom: zoom,
    );

    if (!mounted) return;
    final providerCount = Provider.of<PostProvider>(
      context,
      listen: false,
    ).posts.length;
    debugPrint(
      '[MapPage] _recomputeClusters zoom=${zoom.toStringAsFixed(1)} '
      'bounds=[${bounds.minLatitude.toStringAsFixed(4)}..'
      '${bounds.maxLatitude.toStringAsFixed(4)}, '
      '${bounds.minLongitude.toStringAsFixed(4)}..'
      '${bounds.maxLongitude.toStringAsFixed(4)}] '
      '_posts=$providerCount cluster_results=${results.length}',
    );

    // pinned post self-clear：consumed = 远端聚合结果已包含该 id（远端权威，
    // 不再需要 pin）；expired = 超过 TTL（避免幽灵）。两条满足任一则清。
    // 与 _clusterResults 更新放进同一个 setState，避免中间帧"既无 pin 又无
    // cluster 包含"的空窗。
    final pinned = _pinnedPost;
    final pinnedAt = _pinnedPostAt;
    final consumed =
        pinned != null &&
        results.any((r) => r is SinglePoint && r.post.id == pinned.id);
    final expired = pinned != null && pinned.isBroadcast
        ? pinned.isExpired
        : pinnedAt != null &&
              DateTime.now().difference(pinnedAt) > _pinnedPostTtl;

    setState(() {
      _clusterResults = results;
      if (consumed || expired) {
        if (pinned != null) {
          debugPrint(
            '[MapPage] pinned-clear id=${pinned.id} '
            'reason=${consumed ? "cluster-included" : "ttl-expired"}',
          );
        }
        _pinnedPost = null;
        _pinnedPostAt = null;
      }
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

    // 优先用 async 预取的精确原生坐标（含 3D pitch / bearing 修正）。
    // Cache miss 时回退到同步 Mercator 计算，确保气泡不会因为 async cache
    // 还没填上就消失——这是修复"发布后看不到刚发的 post bubble"的关键。
    //
    // 已知 async cache miss 的高发场景：
    //  1. addNewPost 触发 Consumer rebuild + postFrameCallback 重算，但
    //     `_postScreenPoints.clear()` 与 _focusPublishedPost 的 setState 在
    //     同一帧内连发，新 post 的 key 还没机会落进 cache；
    //  2. moveTo 动画期间多次 _updatePostPositionsAsync 重入，`_isUpdatingPositions`
    //     守卫导致部分调用被丢；
    //  3. `getVisibleBounds()` 在动画 mid-flight 偶发 throw → cluster 重算静默失败。
    //
    // 同步 fallback 不依赖任何 async 链路，只要 controller 与 viewport 就绪
    // 就一定返回非 null（精度足够首帧定位，下一次 async tick 自动 refine）。
    final controller = _jogyMapController;
    final asyncPoint = _postScreenPoints['p_${post.id}'];
    final screenPoint =
        asyncPoint ??
        controller?.latLngToScreenPoint(
          MapLatLng(post.location.latitude, post.location.longitude),
        );
    if (screenPoint == null) return const SizedBox.shrink();
    if (asyncPoint == null) {
      // Cache miss → 走 sync fallback。打一行只在第一次出现新 id 时有意义的日志，
      // 帮助验收时确认刚发布的 post 是不是命中了这条 fallback。
      debugPrint(
        '[MapPage] _buildBubbleOverlay sync-fallback id=${post.id} '
        'pt=(${screenPoint.x.toStringAsFixed(1)},${screenPoint.y.toStringAsFixed(1)})',
      );
    }

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
              MaterialPageRoute(builder: (c) => DetailPage(postId: post.id)),
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
              final viewportSize = _jogyMapController!.cameraState.viewportSize;
              final offset = _expandedBubbleCenterOffset(viewportSize);
              final target = MapLatLng(
                post.location.latitude,
                post.location.longitude,
              );
              final adjustedCenter = MapGeoUtils.adjustCenterForScreenOffset(
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

  /// 构建聚合/单点覆盖层（cluster-aware）。
  ///
  /// **DEAD CODE**：build 已改用 [PostBubblesOverlay]，该方法不再被调用。
  /// 暂留以避免删除时连带触发 `_pinnedPost` / `_clusterResults` /
  /// `_postScreenPoints` / `_lastPostsSignature` 等一连串 unused 警告 —— 它们
  /// 还有其它写入点，需要更大范围的 cleanup PR。本次只做最小改动让 bubble 出来。
  // ignore: unused_element
  Widget _buildItemOverlay(ClusterOrPoint item, List<PostModel> posts) {
    if (item is SinglePoint) {
      // 找到 item.post 在 posts 列表中的 index，沿用原有的自动展开/scale 体系
      final idx = posts.indexWhere((p) => p.id == item.post.id);
      if (idx < 0) return const SizedBox.shrink();
      return _buildBubbleOverlay(posts, idx);
    }

    // ClusterNode 分支
    final cluster = item as ClusterNode;
    // 同上：async cache miss 时退到同步 Mercator，避免 cluster 圆圈瞬时消失。
    final controller = _jogyMapController;
    final screenPoint =
        _postScreenPoints[cluster.id] ??
        controller?.latLngToScreenPoint(cluster.center);
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

        // Posts 刷新后（数量 / 任一项的 id 或坐标变化），重建聚合索引 + 重新计算屏幕坐标。
        //
        // 之前的签名只看 posts.length 和 posts[0] 的坐标——同 length 但中间项变化、
        // 或同 id 但坐标被远端纠正等 corner case 会漏 reload。改用全量 id+坐标的列表签名：
        // posts 数量级 ~10²，每帧 join 成本可忽略，但能稳定捕捉所有数据变化。
        final postsSignature = posts.isEmpty
            ? ''
            : posts
                  .map(
                    (p) =>
                        '${p.id}:${p.location.latitude}:${p.location.longitude}',
                  )
                  .join('|');
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
        final renderItems = _clusterResults.isNotEmpty
            ? List<ClusterOrPoint>.from(_clusterResults)
            : posts.map<ClusterOrPoint>(SinglePoint.new).toList();

        // 强制 pin 兜底：刚发布的 post 即使被 cluster_results / supercluster /
        // 过期 filter / discover 评分等任一环节吞掉，也保证它在屏幕上一定出现。
        // 详见 [_pinnedPost] 文档；self-clear 在 [_recomputeClusters]。
        final pinned = _pinnedPost;
        if (pinned != null) {
          final already = renderItems.any(
            (it) => it is SinglePoint && it.post.id == pinned.id,
          );
          if (!already) {
            renderItems.add(SinglePoint(pinned));
            debugPrint('[MapPage] pinned-overlay injecting id=${pinned.id}');
          }
        }
        if (_expandedIndex != null && _expandedIndex! < posts.length) {
          final expandedPostId = posts[_expandedIndex!].id;
          renderItems.sort((a, b) {
            final aIsExpanded = a is SinglePoint && a.post.id == expandedPostId;
            final bIsExpanded = b is SinglePoint && b.post.id == expandedPostId;
            if (aIsExpanded && !bIsExpanded) return 1;
            if (!aIsExpanded && bIsExpanded) return -1;
            return 0;
          });
        }

        // 使用用户位置作为中心，如果获取失败则使用第一个 post 位置或 fallback
        final mapCenter =
            _userLocation ??
            (posts.isNotEmpty
                ? MapLatLng(
                    posts[0].location.latitude,
                    posts[0].location.longitude,
                  )
                : const MapLatLng(39.9042, 116.4074));

        return Stack(
          children: [
            Positioned.fill(
              child: GesturePassthroughStack(
                fit: StackFit.expand,
                children: [
                  // 基础地图 Widget（由 Mapbox 适配器构建）
                  MapboxMapWidgetBuilder(
                    styleUri: MapConfig.mapboxStyleUri,
                  ).build(
                    JogyMapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 17.0,
                      initialPitch: 45.0,
                      onMapCreated: (controller) {
                        final viewport = controller.cameraState.viewportSize;
                        debugPrint(
                          '[MapPage] onMapCreated posts=${posts.length} '
                          'viewport=${viewport.x.toStringAsFixed(0)}x'
                          '${viewport.y.toStringAsFixed(0)}',
                        );
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
                    ),
                  ),
                  // 标记覆盖层。新版用 [PostBubblesOverlay]：
                  //  - 不依赖 _isViewportReady gate（视口未就绪时该条静默 skip，下个 tick 自动补上）；
                  //  - 不依赖 _clusterResults / _postScreenPoints 异步 cache；
                  //  - 每次 _onCameraMove → _cameraTick.value++ 触发 overlay 内部 setState。
                  //
                  // GesturePassthroughStack 会让 bubble 和底层 MapWidget 同时进入
                  // gesture arena：tap 仍由 bubble 处理，pan / pinch / rotate 交给 Mapbox。
                  //
                  // 旧的 renderItems / _buildItemOverlay / _pinnedPost / cluster engine
                  // 路径暂时保留为 dead state（cleanup 留到后续 PR），避免一次性删动
                  // 太多关联点（_clusterResults、_pinnedPost、_postScreenPoints、
                  // _lastPostsSignature 等）。
                  if (_jogyMapController != null)
                    PostBubblesOverlay(
                      controller: _jogyMapController!,
                      cameraTick: _cameraTick,
                      posts: posts,
                      mapRotation: _mapRotation,
                      expandedIndex: _expandedIndex,
                      scaleFactors: _scaleFactors,
                      onTap: _handleBubbleTap,
                      onBroadcastLike: _handleBroadcastLike,
                      onBroadcastReply: _startBroadcastReply,
                    ),
                  if (_selectedSearchPlace != null)
                    _buildSearchPlaceMarker(_selectedSearchPlace!),
                ],
              ),
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
                  setState(() {
                    _selectedSearchPlace = null;
                  });
                  // 重新进入 FollowPuck 模式（跟随位置 + 朝向旋转）
                  _jogyMapController?.followUserWithHeading(zoom: 17);
                },
              ),
            ),
            if (_replyingBroadcast != null) _buildBroadcastReplyComposer(),
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
    final authService = context.read<AuthService>();
    final cachedUser = authService.currentUser;
    final cachedUserId = authService.currentUserId;
    final Future<UserModel?> userFuture = cachedUser != null
        ? Future<UserModel?>.value(cachedUser)
        : RemoteDataSource().getCurrentUser();

    // 先显示 loading，异步获取真实用户数据
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FutureBuilder<UserModel?>(
          future: userFuture,
          builder: (context, snapshot) {
            // 获取到用户数据或失败后都显示 dialog
            final user = snapshot.data ?? cachedUser;
            final username = user?.username ?? 'Jogy User';
            final avatarUrl = user?.avatarUrl ?? '';
            final userId = (user?.id ?? cachedUserId ?? '').trim();
            final qrData = userId.isNotEmpty
                ? JogyQrCodec.userProfile(userId)
                : null;
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                qrData == null;

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
                    else if (qrData == null) ...[
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFE57373),
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '无法生成二维码',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '请重新登录后再试',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ] else ...[
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
  String _selectedDuration = '30分钟'; // 留存时长
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入内容')));
      return;
    }
    if (_isImageMode && _selectedPostImages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请添加照片，或切换为广播')));
      return;
    }
    if (_currentLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在获取位置，请稍候')));
      return;
    }

    debugPrint('[_handlePublish] start, images=${_selectedPostImages.length}');
    setState(() => _isPublishing = true);

    try {
      final remote = RemoteDataSource();

      // 1. Upload images in parallel
      debugPrint('[_handlePublish] uploading images...');
      List<String> mediaUrls = [];
      if (_isImageMode && _selectedPostImages.isNotEmpty) {
        final uploadFutures = _selectedPostImages
            .map((file) => remote.uploadImage(file.path))
            .toList();
        mediaUrls = await Future.wait(uploadFutures);
      }
      debugPrint('[_handlePublish] images uploaded: $mediaUrls');

      // 2. Create the post
      final postType = _isImageMode ? 'bubble' : 'broadcast';
      final title = _isImageMode ? _titleController.text.trim() : '';
      final expireAt = _durationToExpireAt(_selectedDuration);

      debugPrint('[_handlePublish] calling createPost...');
      final newPost = await remote.createPost(
        contentText: content,
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        postType: postType,
        title: title.isNotEmpty ? title : null,
        addressName: _currentLocation!.placeName ?? _currentLocation!.address,
        mediaUrls: _isImageMode && mediaUrls.isNotEmpty ? mediaUrls : null,
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

      // 4. 关闭发布 sheet，并把新 post 返回给 MapPage。
      //
      // PostProvider 写入、toast、地图 moveTo 都由父级 MapPage 处理。这样可以保证
      // 使用的是地图所在页面的 context / controller，避免 bottom sheet 内部更新后
      // 地图视口仍停留在别处而看不到刚发布的 post。
      Navigator.pop(context, newPost);
      debugPrint('[_handlePublish] done');
    } catch (e, st) {
      debugPrint('[_handlePublish] FAILED: $e\n$st');
      if (!mounted) return;
      setState(() => _isPublishing = false);

      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发布失败：$msg')));
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
              _selectedPostImages.addAll(paths.map((e) => File(e.toString())));
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
          if (draft['location_lat'] != null && draft['location_lng'] != null) {
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
