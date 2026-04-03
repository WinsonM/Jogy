import 'dart:math' as math;

/// 平台无关的地图数据类型
/// 所有地图相关代码应使用这些类型，而非特定 SDK 的类型（如 latlong2.LatLng）

/// 地理坐标
class MapLatLng {
  final double latitude;
  final double longitude;

  const MapLatLng(this.latitude, this.longitude);

  @override
  String toString() => 'MapLatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      other is MapLatLng &&
      latitude == other.latitude &&
      longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// 屏幕坐标点
class MapScreenPoint {
  final double x;
  final double y;

  const MapScreenPoint(this.x, this.y);

  @override
  String toString() => 'MapScreenPoint($x, $y)';
}

/// 相机状态（只读快照）
class MapCameraState {
  final MapLatLng center;
  final double zoom;
  final double pitch;

  /// 旋转角度（度，顺时针为正）
  final double bearing;

  /// 视口尺寸（像素）
  final MapScreenPoint viewportSize;

  const MapCameraState({
    required this.center,
    required this.zoom,
    this.pitch = 0,
    this.bearing = 0,
    this.viewportSize = const MapScreenPoint(0, 0),
  });
}

/// 相机移动事件来源
enum MapMoveSource {
  gesture, // 用户手势（拖拽、缩放等）
  animation, // 程序动画
  programmatic, // 程序直接设置
  unknown,
}

/// 地图事件
class MapCameraEvent {
  final MapCameraState camera;
  final MapMoveSource source;

  const MapCameraEvent({
    required this.camera,
    this.source = MapMoveSource.unknown,
  });
}

/// 地图提供商枚举
enum MapProviderType {
  mapbox,
  amap, // 高德地图（预留）
}

/// 地图地理工具类
class MapGeoUtils {
  /// 计算调整后的地图中心，使 [target] 出现在屏幕中心偏移 [offsetX], [offsetY] 的位置。
  ///
  /// 基于 Web Mercator 投影计算。
  /// [offsetX] 和 [offsetY] 是屏幕像素偏移（正 Y = 向下）。
  static MapLatLng adjustCenterForScreenOffset(
    MapLatLng target,
    double zoom,
    double offsetX,
    double offsetY,
  ) {
    final scale = 256.0 * math.pow(2, zoom);

    // 目标点的 Mercator 像素坐标
    final tx = (target.longitude + 180.0) / 360.0 * scale;
    final latRad = target.latitude * math.pi / 180.0;
    final ty = (1.0 -
            math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
        2.0 *
        scale;

    // 地图中心 = 目标 - 偏移
    final cx = tx - offsetX;
    final cy = ty - offsetY;

    // 反向转换为经纬度
    final lng = cx / scale * 360.0 - 180.0;
    final n = math.pi * (1 - 2 * cy / scale);
    final lat = (2 * math.atan(math.exp(n)) - math.pi / 2) * 180.0 / math.pi;

    return MapLatLng(lat, lng);
  }
}
