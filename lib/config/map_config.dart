/// 地图配置文件
/// 请在此处配置你的地图 API key
class MapConfig {
  // Mapbox API Key
  static const String mapboxApiKey = '[REDACTED_LEAKED_MAPBOX_TOKEN]';

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
