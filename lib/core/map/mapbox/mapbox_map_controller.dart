import 'dart:math' as math;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../map_types.dart';
import '../map_controller.dart';

/// Mapbox 地图控制器适配器
///
/// 将 [mapbox.MapboxMap] 的 API 适配为 [JogyMapController] 接口。
class MapboxMapController implements JogyMapController {
  final mapbox.MapboxMap _mapboxMap;
  MapCameraState _lastCameraState;

  /// 标记是否正在执行程序化动画（flyTo / setCamera）
  bool _isAnimating = false;
  bool get isAnimating => _isAnimating;

  MapboxMapController(this._mapboxMap, this._lastCameraState);

  /// 获取原生 MapboxMap 实例（仅在需要 Mapbox 特有功能时使用）
  mapbox.MapboxMap get nativeMap => _mapboxMap;

  @override
  MapCameraState get cameraState => _lastCameraState;

  /// 由外部事件回调更新缓存的相机状态
  void updateCameraState(MapCameraState state) {
    _lastCameraState = state;
  }

  @override
  Future<void> moveTo(
    MapLatLng center, {
    double? zoom,
    double? pitch,
    double? bearing,
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    final cameraOptions = mapbox.CameraOptions(
      center: mapbox.Point(
        coordinates: mapbox.Position(center.longitude, center.latitude),
      ),
      zoom: zoom,
      pitch: pitch,
      bearing: bearing,
    );

    _isAnimating = true;
    try {
      if (duration.inMilliseconds > 0) {
        await _mapboxMap.flyTo(
          cameraOptions,
          mapbox.MapAnimationOptions(duration: duration.inMilliseconds),
        );
      } else {
        await _mapboxMap.setCamera(cameraOptions);
      }
    } finally {
      _isAnimating = false;
    }
  }

  @override
  MapScreenPoint? latLngToScreenPoint(MapLatLng latLng) {
    // 基于 Web Mercator 投影的同步近似计算
    // 适用于标记定位和自动展开检测等实时计算场景
    final state = _lastCameraState;
    final vw = state.viewportSize.x;
    final vh = state.viewportSize.y;
    if (vw == 0 || vh == 0) return null;

    // Mapbox 底层投影使用 size=512 作为 zoom 0 的基准
    final scale = 512.0 * math.pow(2, state.zoom);

    final centerPx = _latLngToMercator(state.center, scale);
    final pointPx = _latLngToMercator(latLng, scale);

    // 考虑 bearing 旋转
    var dx = pointPx.x - centerPx.x;
    var dy = pointPx.y - centerPx.y;
    if (state.bearing != 0) {
      final rad = state.bearing * math.pi / 180; // 修复：顺时针旋转，屏幕系内相当于向量逆时针旋转
      final cosR = math.cos(rad);
      final sinR = math.sin(rad);
      final rx = dx * cosR + dy * sinR;
      final ry = -dx * sinR + dy * cosR;
      dx = rx;
      dy = ry;
    }

    // 3D Pitch 投影近似修正
    // 在倾斜视角下，Y轴距离会根据透视缩短。在中心点附近的简单近似
    if (state.pitch > 0) {
      final pitchRad = state.pitch * math.pi / 180;
      // 简单近似：将 Y 轴的距离压缩
      dy *= math.cos(pitchRad);
    }

    return MapScreenPoint(dx + vw / 2, dy + vh / 2);
  }

  /// 异步版本的坐标转换（通过原生 SDK 精确计算）
  Future<MapScreenPoint?> latLngToScreenPointAsync(MapLatLng latLng) async {
    try {
      final screenCoord = await _mapboxMap.pixelForCoordinate(
        mapbox.Point(
          coordinates: mapbox.Position(latLng.longitude, latLng.latitude),
        ),
      );
      return MapScreenPoint(screenCoord.x, screenCoord.y);
    } catch (_) {
      return null;
    }
  }

  @override
  MapLatLng? screenPointToLatLng(MapScreenPoint point) {
    // 同步版暂不实现，使用异步版
    return null;
  }

  /// 异步版本的屏幕坐标转地理坐标
  Future<MapLatLng?> screenPointToLatLngAsync(MapScreenPoint point) async {
    try {
      final coord = await _mapboxMap.coordinateForPixel(
        mapbox.ScreenCoordinate(x: point.x, y: point.y),
      );
      final pos = coord.coordinates;
      return MapLatLng(pos.lat.toDouble(), pos.lng.toDouble());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MapBounds?> getVisibleBounds() async {
    try {
      final state = _lastCameraState;
      final vw = state.viewportSize.x;
      final vh = state.viewportSize.y;
      if (vw == 0 || vh == 0) return null;

      // 查询屏幕四角对应的地理坐标
      final topLeft = await _mapboxMap.coordinateForPixel(
        mapbox.ScreenCoordinate(x: 0, y: 0),
      );
      final topRight = await _mapboxMap.coordinateForPixel(
        mapbox.ScreenCoordinate(x: vw, y: 0),
      );
      final bottomLeft = await _mapboxMap.coordinateForPixel(
        mapbox.ScreenCoordinate(x: 0, y: vh),
      );
      final bottomRight = await _mapboxMap.coordinateForPixel(
        mapbox.ScreenCoordinate(x: vw, y: vh),
      );

      final lats = [
        topLeft.coordinates.lat.toDouble(),
        topRight.coordinates.lat.toDouble(),
        bottomLeft.coordinates.lat.toDouble(),
        bottomRight.coordinates.lat.toDouble(),
      ];
      final lngs = [
        topLeft.coordinates.lng.toDouble(),
        topRight.coordinates.lng.toDouble(),
        bottomLeft.coordinates.lng.toDouble(),
        bottomRight.coordinates.lng.toDouble(),
      ];

      return MapBounds(
        southwest: MapLatLng(lats.reduce(math.min), lngs.reduce(math.min)),
        northeast: MapLatLng(lats.reduce(math.max), lngs.reduce(math.max)),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> enableLocationPuck() async {
    try {
      await _mapboxMap.location.updateSettings(
        mapbox.LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: false,
          locationPuck: mapbox.LocationPuck(
            locationPuck2D: mapbox.DefaultLocationPuck2D(),
          ),
        ),
      );
    } catch (_) {
      // 定位组件启用失败（权限等原因），静默处理
    }
  }

  @override
  void dispose() {
    // MapboxMap 的生命周期由 MapWidget 管理
  }

  /// Web Mercator 投影：经纬度 → 像素坐标
  static _MercatorPoint _latLngToMercator(MapLatLng latLng, double scale) {
    final x = (latLng.longitude + 180.0) / 360.0 * scale;
    final latRad = latLng.latitude * math.pi / 180.0;
    final y = (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * scale;
    return _MercatorPoint(x, y);
  }
}

class _MercatorPoint {
  final double x;
  final double y;
  const _MercatorPoint(this.x, this.y);
}
