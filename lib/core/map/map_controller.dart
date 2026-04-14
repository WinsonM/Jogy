import 'map_types.dart';

/// 抽象地图控制器
///
/// 定义所有地图操作的统一接口。
/// 具体实现由各地图 SDK 适配器提供（Mapbox、高德等）。
abstract class JogyMapController {
  /// 当前相机状态
  MapCameraState get cameraState;

  /// 移动到指定位置（带动画）
  ///
  /// [center] 目标中心点
  /// [zoom] 目标缩放级别（null 则保持当前值）
  /// [pitch] 目标倾斜角度（null 则保持当前值）
  /// [bearing] 目标旋转角度（null 则保持当前值）
  /// [duration] 动画时长
  Future<void> moveTo(
    MapLatLng center, {
    double? zoom,
    double? pitch,
    double? bearing,
    Duration duration = const Duration(milliseconds: 500),
  });

  /// 地理坐标 → 屏幕坐标
  ///
  /// 将经纬度转换为当前视口中的像素坐标。
  /// 用于在 Stack overlay 中定位 Flutter widget（如气泡标记）。
  /// 经纬度转屏幕坐标（可能因实现而产生逼近误差）
  MapScreenPoint? latLngToScreenPoint(MapLatLng latLng);

  /// 异步精确经纬度转屏幕坐标（利用原生引擎完整管线解析，包含3D等特性）
  Future<MapScreenPoint?> latLngToScreenPointAsync(MapLatLng latLng) async {
    // 默认回退到同步的计算，适配器可覆盖
    return latLngToScreenPoint(latLng);
  }

  /// 屏幕坐标 → 地理坐标
  MapLatLng? screenPointToLatLng(MapScreenPoint point);

  /// 获取当前可视范围（西南角 + 东北角）
  Future<MapBounds?> getVisibleBounds();

  /// 启用原生定位 puck（蓝色圆点）
  /// [showHeading] 为 true 时显示设备朝向箭头
  Future<void> enableLocationPuck({bool showHeading = false});

  /// 释放资源
  void dispose();
}
