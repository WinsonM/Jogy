import 'package:flutter/widgets.dart';

/// 将设备 locale 映射到 Mapbox Geocoding / Tilequery 支持的语言代码。
///
/// 不在支持集的回退 'en'。传入 [locale] 可覆盖默认的 platformDispatcher.locale
/// （用于测试或需要强制某种语言的场景）。
///
/// 支持集来自 Mapbox Geocoding v5 `language` 参数官方文档。
String mapboxLanguage([Locale? locale]) {
  final code =
      (locale ?? WidgetsBinding.instance.platformDispatcher.locale).languageCode;
  const supported = {
    'ar', 'de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'pt', 'ru', 'zh',
  };
  return supported.contains(code) ? code : 'en';
}
