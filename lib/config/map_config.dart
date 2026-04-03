import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/map/map_types.dart';

/// 地图配置文件
/// 请在此处配置你的地图 API key 和样式
class MapConfig {
  // Mapbox API Key fetched from .env
  static String get mapboxApiKey => dotenv.env['MAPBOX_API_KEY'] ?? '';

  // 当前使用的地图提供商
  static const MapProviderType provider = MapProviderType.mapbox;

  // Mapbox GL 自定义样式 URI（通过 Mapbox Studio 发布）
  // Dawn 光照预设 + 3D 建筑
  static const String mapboxStyleUri =
      'mapbox://styles/winsonmalone/cmmoict5a004601rng9msbkgn';

  // 备用：Mapbox 标准样式
  static const String mapboxStandardStyleUri = 'mapbox://styles/mapbox/standard';

  // ── 以下为旧版栅格瓦片 URL（flutter_map 时代遗留，保留备用） ──

  // Mapbox 日间模式 (Streets)
  static String get tileUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxApiKey';

  // 备用：Mapbox 夜间模式 (Dark)
  static String get tileUrlNight =>
      'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxApiKey';

  // 备用：Mapbox 卫星图 (Satellite)
  static String get tileUrlSatellite =>
      'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxApiKey';
}
