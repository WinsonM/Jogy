import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../map_types.dart';
import '../map_widget_builder.dart';
import 'mapbox_map_controller.dart';

/// Mapbox 地图 Widget 构建器
///
/// 使用 [mapbox.MapWidget] 构建原生 Mapbox GL 地图。
/// 支持 3D 建筑、倾斜视角等高级渲染特性。
/// 默认启用 FollowPuckViewportState + Heading，地图跟随用户位置并随设备朝向旋转。
class MapboxMapWidgetBuilder implements JogyMapWidgetBuilder {
  /// 自定义 Mapbox 样式 URI
  /// 如果为 null，则使用 Mapbox 默认样式
  final String? styleUri;

  MapboxMapWidgetBuilder({this.styleUri});

  @override
  Widget build(JogyMapOptions options) {
    return _MapboxMapWrapper(options: options, styleUri: styleUri);
  }
}

/// 内部 StatefulWidget，用于管理 MapboxMap 的生命周期
class _MapboxMapWrapper extends StatefulWidget {
  final JogyMapOptions options;
  final String? styleUri;

  const _MapboxMapWrapper({required this.options, this.styleUri});

  @override
  State<_MapboxMapWrapper> createState() => _MapboxMapWrapperState();
}

class _MapboxMapWrapperState extends State<_MapboxMapWrapper> {
  MapboxMapController? _controller;

  /// 当前 viewport 状态。初始为 FollowPuck（跟随用户 + 朝向旋转）。
  /// 用户手势拖动时 Mapbox SDK 自动切换为 Idle。
  /// 点击定位按钮时通过 [_activateFollowMode] 重新进入 FollowPuck。
  mapbox.ViewportState? _viewport;

  @override
  void initState() {
    super.initState();
    // 只有首页地图默认开启 FollowPuck（跟随位置 + 朝向旋转）
    // Profile 地图等静态场景不需要
    if (widget.options.followHeadingOnStart) {
      _viewport = _createFollowPuckViewport();
    }
  }

  mapbox.FollowPuckViewportState _createFollowPuckViewport({
    double? zoom,
    double? pitch,
  }) {
    return mapbox.FollowPuckViewportState(
      zoom: zoom ?? widget.options.initialZoom,
      bearing: const mapbox.FollowPuckViewportStateBearingHeading(),
      pitch: pitch ?? widget.options.initialPitch,
    );
  }

  /// 重新激活 FollowPuck viewport（由定位按钮触发）
  void _activateFollowMode({double? zoom, double? pitch}) {
    // 创建新的 FollowPuckViewportState 实例，Mapbox 检测到变化后重新应用
    setStateWithViewportAnimation(() {
      _viewport = _createFollowPuckViewport(zoom: zoom, pitch: pitch);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) {
    // 创建初始相机状态
    final initialState = MapCameraState(
      center: widget.options.initialCenter,
      zoom: widget.options.initialZoom,
      pitch: widget.options.initialPitch,
      bearing: widget.options.initialBearing,
      viewportSize: _readViewportSizeFallback(),
    );

    _controller = MapboxMapController(mapboxMap, initialState);

    // 注入回调：让 controller.followUserWithHeading() 能触发 viewport 切换
    _controller!.onRequestFollowHeading = _activateFollowMode;

    // 通知外部地图创建完成
    widget.options.onMapCreated?.call(_controller!);

    // 首次创建后立即尝试同步一次相机状态（含视口尺寸）
    _updateCameraState(MapMoveSource.programmatic);
    // Mapbox onMapCreated 可能早于 Flutter layout / native getSize 可用。
    // 下一帧再同步一次并触发 idle，让 overlay 和聚合都有机会拿到非 0 viewport。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateCameraState(MapMoveSource.programmatic, notifyIdle: true);
    });
  }

  void _onCameraChanged(mapbox.CameraChangedEventData event) {
    final controller = _controller;
    if (controller == null) return;

    // 根据控制器是否正在执行程序化动画来判断事件来源
    final source = controller.isAnimating
        ? MapMoveSource.animation
        : MapMoveSource.gesture;
    var viewportSize = controller.cameraState.viewportSize;
    if (viewportSize.x <= 0 || viewportSize.y <= 0) {
      viewportSize = _readViewportSizeFallback();
    }

    final center = event.cameraState.center.coordinates;
    final newState = MapCameraState(
      center: MapLatLng(center.lat.toDouble(), center.lng.toDouble()),
      zoom: event.cameraState.zoom,
      pitch: event.cameraState.pitch,
      bearing: event.cameraState.bearing,
      viewportSize: viewportSize,
    );

    controller.updateCameraState(newState);
    widget.options.onCameraMove?.call(
      MapCameraEvent(camera: newState, source: source),
    );
  }

  void _onMapLoaded(mapbox.MapLoadedEventData event) {
    _updateCameraState(MapMoveSource.programmatic);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateCameraState(MapMoveSource.programmatic, notifyIdle: true);
    });
    // 地图加载完成后启用原生定位 puck（带朝向箭头）
    _controller?.enableLocationPuck();
  }

  void _onMapIdle(mapbox.MapIdleEventData event) {
    // Idle 路径：刷新相机状态 + 广播 idle 事件给订阅者
    _updateCameraState(MapMoveSource.programmatic, notifyIdle: true);
  }

  Future<void> _updateCameraState(
    MapMoveSource source, {
    bool notifyIdle = false,
  }) async {
    if (_controller == null) return;

    try {
      final nativeMap = _controller!.nativeMap;
      final cameraState = await nativeMap.getCameraState();
      final nativeSize = await nativeMap.getSize();
      var width = nativeSize.width.toDouble();
      var height = nativeSize.height.toDouble();
      if (width <= 0 || height <= 0) {
        final fallback = _readViewportSizeFallback();
        width = fallback.x;
        height = fallback.y;
      }

      final center = cameraState.center.coordinates;
      final newState = MapCameraState(
        center: MapLatLng(center.lat.toDouble(), center.lng.toDouble()),
        zoom: cameraState.zoom,
        pitch: cameraState.pitch,
        bearing: cameraState.bearing,
        viewportSize: MapScreenPoint(width, height),
      );

      _controller!.updateCameraState(newState);

      final event = MapCameraEvent(camera: newState, source: source);

      // 触发外部回调
      widget.options.onCameraMove?.call(event);

      if (notifyIdle) {
        // 广播给 controller 的 stream 订阅者（聚合模块等）
        _controller!.emitCameraIdle(event);
        // 触发外部 onCameraIdle 回调
        widget.options.onCameraIdle?.call(event);
      }
    } catch (_) {
      // 地图可能正在初始化
    }
  }

  MapScreenPoint _readViewportSizeFallback() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final size = renderObject.size;
      if (size.width > 0 && size.height > 0) {
        return MapScreenPoint(size.width, size.height);
      }
    }

    final media = MediaQuery.maybeOf(context);
    if (media != null && media.size.width > 0 && media.size.height > 0) {
      return MapScreenPoint(media.size.width, media.size.height);
    }

    return const MapScreenPoint(0, 0);
  }

  void _onTapListener(mapbox.MapContentGestureContext context) {
    final point = context.point;
    final coords = point.coordinates;
    widget.options.onTap?.call(
      MapLatLng(coords.lat.toDouble(), coords.lng.toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.options.initialCenter;

    return mapbox.MapWidget(
      styleUri: widget.styleUri ?? mapbox.MapboxStyles.STANDARD,
      cameraOptions: mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(center.longitude, center.latitude),
        ),
        zoom: widget.options.initialZoom,
        pitch: widget.options.initialPitch,
        bearing: widget.options.initialBearing,
      ),
      viewport: _viewport,
      // 让地图参与 tap / scale 手势竞争。不要用 EagerGestureRecognizer：
      // home map 的 Flutter bubble overlay 会与 MapWidget 同时命中；Eager 会抢走
      // bubble 的点击。Scale 负责 pan / pinch / rotate 这一组连续地图手势，
      // Tap 保留地图空白处点击。不要同时注册 Pan：单指拖移时 Pan 会先赢
      // gesture arena，之后同一轮手势再加第二根手指时 Scale 已经无法接管旋转。
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
        Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
      },
      onMapCreated: _onMapCreated,
      onMapLoadedListener: _onMapLoaded,
      onMapIdleListener: _onMapIdle,
      onCameraChangeListener: _onCameraChanged,
      onTapListener: _onTapListener,
    );
  }
}
