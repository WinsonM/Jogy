import 'package:flutter/widgets.dart';
import 'map_types.dart';
import 'map_controller.dart';

/// 地图 Widget 构建配置
class JogyMapOptions {
  /// 初始中心点
  final MapLatLng initialCenter;

  /// 初始缩放级别
  final double initialZoom;

  /// 初始倾斜角（度）
  final double initialPitch;

  /// 初始旋转角（度）
  final double initialBearing;

  /// 是否允许旋转手势
  final bool rotationEnabled;

  /// 是否允许倾斜手势
  final bool pitchEnabled;

  /// 是否在地图加载后自动进入 FollowPuck + Heading 模式
  /// 默认 true（首页地图跟随用户朝向），Profile 地图等设为 false
  final bool followHeadingOnStart;

  /// 地图创建完成回调（返回控制器）
  final void Function(JogyMapController controller)? onMapCreated;

  /// 相机移动事件回调
  final void Function(MapCameraEvent event)? onCameraMove;

  /// 相机停止移动事件回调（手势结束 / 动画结束）
  ///
  /// 比 [onCameraMove] 节流：用户拖动/缩放过程中不触发，
  /// 停下后触发一次。用于聚合重算、按视口刷新等懒操作。
  final void Function(MapCameraEvent event)? onCameraIdle;

  /// 地图点击回调
  final void Function(MapLatLng latLng)? onTap;

  const JogyMapOptions({
    required this.initialCenter,
    this.initialZoom = 15.0,
    this.initialPitch = 45.0,
    this.initialBearing = 0,
    this.rotationEnabled = true,
    this.pitchEnabled = true,
    this.followHeadingOnStart = true,
    this.onMapCreated,
    this.onCameraMove,
    this.onCameraIdle,
    this.onTap,
  });
}

/// 抽象地图 Widget 构建器
///
/// 各地图 SDK 适配器需实现此类，返回对应的原生地图 Widget。
abstract class JogyMapWidgetBuilder {
  /// 构建地图 Widget
  ///
  /// 返回的 Widget 只包含地图本身（瓦片/矢量渲染）。
  /// 气泡、标记等 Flutter Widget 应作为 Stack overlay 叠加在上方，
  /// 通过 [JogyMapController.latLngToScreenPoint] 定位。
  Widget build(JogyMapOptions options);
}
