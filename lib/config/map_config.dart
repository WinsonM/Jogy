/// 地图配置文件
/// 请在此处配置你的地图 API key
class MapConfig {
  // TomTom Map API Key
  static const String tomtomApiKey = 'feQ7zmipqtX5ppwT7my5jIf8vLB0q0s7';

  // TomTom 地图瓦片 URL
  static String get tileUrl =>
      'https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=$tomtomApiKey';

  // 备用：TomTom 夜间模式
  static String get tileUrlNight =>
      'https://api.tomtom.com/map/1/tile/basic/night/{z}/{x}/{y}.png?key=$tomtomApiKey';

  // 备用：TomTom 卫星图
  static String get tileUrlSatellite =>
      'https://api.tomtom.com/map/1/tile/sat/main/{z}/{x}/{y}.jpg?key=$tomtomApiKey';
}
