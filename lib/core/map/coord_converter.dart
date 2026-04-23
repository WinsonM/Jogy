import 'map_types.dart';

/// 坐标系转换工具（为 AMap 迁移预留）
///
/// 当前所有数据流均为 WGS84（Mapbox / GPS / 后端存储），本工具暂不启用。
/// 未来引入 AMap 时：
/// - `AmapAdapter.moveTo` 入参 WGS84 → [wgs84ToGcj02] → AMap SDK
/// - `AmapAdapter.screenPointToLatLng` 返回 GCJ-02 → [gcj02ToWgs84] → 出参
/// - 聚合算法层 (`lib/features/map/clustering/`) 永远只处理 WGS84，
///   不感知此转换的存在。
///
/// 保留占位的目的：明确边界契约 —— 未来改动仅限于 AMap 适配器内部，
/// 不会扩散到 feature 层。
class CoordConverter {
  /// WGS84 → GCJ-02（中国大陆火星坐标系）
  ///
  /// 入参：GPS / Mapbox 坐标（WGS84）
  /// 返回：AMap / 腾讯地图可直接显示的 GCJ-02 坐标
  static MapLatLng wgs84ToGcj02(MapLatLng wgs) {
    throw UnimplementedError(
      'CoordConverter.wgs84ToGcj02 未实现。'
      '仅在引入 AMap 适配器时需要实现，当前使用 Mapbox (WGS84)。',
    );
  }

  /// GCJ-02 → WGS84
  ///
  /// 入参：AMap SDK 返回的 GCJ-02 坐标
  /// 返回：统一业务层使用的 WGS84 坐标
  static MapLatLng gcj02ToWgs84(MapLatLng gcj) {
    throw UnimplementedError(
      'CoordConverter.gcj02ToWgs84 未实现。'
      '仅在引入 AMap 适配器时需要实现，当前使用 Mapbox (WGS84)。',
    );
  }
}
