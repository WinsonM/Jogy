import 'map_types.dart';
import 'map_widget_builder.dart';
import 'mapbox/mapbox_map_widget_builder.dart';

/// 地图提供商工厂
///
/// 根据 [MapProviderType] 返回对应的地图 Widget 构建器。
/// 切换地图 SDK 只需更改此处的 provider 类型。
///
/// 示例：
/// ```dart
/// final builder = JogyMapProvider.getBuilder(MapProviderType.mapbox);
/// final mapWidget = builder.build(options);
/// ```
class JogyMapProvider {
  static JogyMapWidgetBuilder getBuilder(MapProviderType type) {
    switch (type) {
      case MapProviderType.mapbox:
        return MapboxMapWidgetBuilder();
      case MapProviderType.amap:
        // TODO: 实现高德地图适配器
        // return AmapMapWidgetBuilder();
        throw UnimplementedError('高德地图适配器尚未实现');
    }
  }
}
