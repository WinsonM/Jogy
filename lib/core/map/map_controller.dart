import 'dart:math' as math;
import 'map_types.dart';

/// 抽象地图控制器
///
/// 定义所有地图操作的统一接口。
/// 具体实现由各地图 SDK 适配器提供（Mapbox、高德等）。
///
/// **AMap 实现注意**：
/// - 坐标系：传入/传出此接口的所有 [MapLatLng] **必须是 WGS84**。
///   AMap 内部使用 GCJ-02，`AmapAdapter` 实现需在边界做转换
///   （见 `lib/core/map/coord_converter.dart`）。
/// - [onCameraIdle]：AMap 用 `AMapController.onCameraMoveEnd` 实现。
/// - [latLngToScreenPoint]：AMap 仅有异步版本，sync 版本可返回 null
///   由调用方走 [latLngToScreenPointAsync] fallback。
abstract class JogyMapController {
  /// 当前相机状态
  MapCameraState get cameraState;

  /// 相机停止移动事件流（用户手势结束 + 程序动画结束都触发）
  ///
  /// 用于聚合重算、按视口刷新等"懒"操作——
  /// 比 camera move 更节流，用户停下手势后才触发一次。
  Stream<MapCameraEvent> get onCameraIdle;

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

  /// 进入跟随用户位置 + 设备朝向模式
  ///
  /// 地图自动居中到用户位置，并根据手机罗盘实时旋转。
  /// 用户手动拖动地图时 SDK 自动退出此模式。
  Future<void> followUserWithHeading({double? zoom, double? pitch});

  /// 地理坐标 → 屏幕坐标
  ///
  /// 将经纬度转换为当前视口中的像素坐标。
  /// 用于在 Stack overlay 中定位 Flutter widget（如气泡标记）。
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

  /// 启用原生定位 puck（蓝色圆点 + 朝向箭头）
  Future<void> enableLocationPuck();

  /// 屏幕像素距离 → 地理度数距离（在指定纬度下）
  ///
  /// 聚合算法用：把 `clusterRadiusPx=80` 在当前 zoom 下换算成"约多少经度度数"，
  /// 作为 `bounds` 查询前的 padding，避免边缘点被遗漏。
  ///
  /// 默认实现走 Web Mercator（Mapbox/标准 tile scheme）：
  /// - 在 zoom 0：整个经度 360° = 512 像素（Mapbox 基准）
  /// - 在 zoom z：360° = 512 * 2^z 像素
  /// - 纬度方向由于 Mercator 非线性，用 `cos(lat)` 做一阶修正
  ///
  /// 适配器若使用不同的基准（如 Google/256）可覆盖。
  double pixelDistanceToDegrees(
    double pixels,
    MapLatLng atLatitude,
    double zoom,
  ) {
    final scale = 512.0 * math.pow(2, zoom);
    // 经度方向：360 度对应 scale 像素
    final degreesPerPixelLng = 360.0 / scale;
    // 用经度度数作为近似的对角半径（聚合 padding 不需要精确各向异性）
    return pixels * degreesPerPixelLng;
  }

  /// 释放资源
  void dispose();
}
