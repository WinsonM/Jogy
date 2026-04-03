import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../map_types.dart';
import '../map_controller.dart';
import '../map_widget_builder.dart';
import 'mapbox_map_controller.dart';

/// Mapbox 地图 Widget 构建器
///
/// 使用 [mapbox.MapWidget] 构建原生 Mapbox GL 地图。
/// 支持 3D 建筑、倾斜视角等高级渲染特性。
class MapboxMapWidgetBuilder implements JogyMapWidgetBuilder {
  /// 自定义 Mapbox 样式 URI
  /// 如果为 null，则使用 Mapbox 默认样式
  final String? styleUri;

  MapboxMapWidgetBuilder({this.styleUri});

  @override
  Widget build(JogyMapOptions options) {
    return _MapboxMapWrapper(
      options: options,
      styleUri: styleUri,
    );
  }
}

/// 内部 StatefulWidget，用于管理 MapboxMap 的生命周期
class _MapboxMapWrapper extends StatefulWidget {
  final JogyMapOptions options;
  final String? styleUri;

  const _MapboxMapWrapper({
    required this.options,
    this.styleUri,
  });

  @override
  State<_MapboxMapWrapper> createState() => _MapboxMapWrapperState();
}

class _MapboxMapWrapperState extends State<_MapboxMapWrapper> {
  MapboxMapController? _controller;

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
    );

    _controller = MapboxMapController(mapboxMap, initialState);

    // 通知外部地图创建完成
    widget.options.onMapCreated?.call(_controller!);

    // 首次创建后立即尝试同步一次相机状态（含视口尺寸）
    // 如果地图仍在初始化，后续 onMapLoaded/onMapIdle 会再次触发同步。
    _updateCameraState(MapMoveSource.programmatic);
  }

  void _onCameraChanged(mapbox.CameraChangedEventData event) {
    // 根据控制器是否正在执行程序化动画来判断事件来源
    final source = (_controller?.isAnimating ?? false)
        ? MapMoveSource.animation
        : MapMoveSource.gesture;
    _updateCameraState(source);
  }

  void _onMapLoaded(mapbox.MapLoadedEventData event) {
    _updateCameraState(MapMoveSource.programmatic);
  }

  void _onMapIdle(mapbox.MapIdleEventData event) {
    _updateCameraState(MapMoveSource.programmatic);
  }

  Future<void> _updateCameraState(MapMoveSource source) async {
    if (_controller == null) return;

    try {
      final nativeMap = _controller!.nativeMap;
      final cameraState = await nativeMap.getCameraState();
      final size = await nativeMap.getSize();

      final center = cameraState.center.coordinates;
      final newState = MapCameraState(
        center: MapLatLng(center.lat.toDouble(), center.lng.toDouble()),
        zoom: cameraState.zoom,
        pitch: cameraState.pitch,
        bearing: cameraState.bearing,
        viewportSize: MapScreenPoint(
          size.width.toDouble(),
          size.height.toDouble(),
        ),
      );

      _controller!.updateCameraState(newState);

      // 触发外部回调
      widget.options.onCameraMove?.call(MapCameraEvent(
        camera: newState,
        source: source,
      ));
    } catch (_) {
      // 地图可能正在初始化
    }
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
      // 让地图在嵌套滚动容器（如 Profile 的 SingleChildScrollView）中优先接管拖拽手势
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onMapCreated: _onMapCreated,
      onMapLoadedListener: _onMapLoaded,
      onMapIdleListener: _onMapIdle,
      onCameraChangeListener: _onCameraChanged,
      onTapListener: _onTapListener,
    );
  }
}
