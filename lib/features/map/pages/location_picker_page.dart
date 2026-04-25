import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../config/map_config.dart';
import '../../../core/map/map_controller.dart';
import '../../../core/map/map_types.dart';
import '../../../core/map/map_widget_builder.dart';
import '../../../core/map/mapbox/mapbox_map_widget_builder.dart';
import '../../../data/models/location_model.dart';
import '../../../utils/mapbox_language.dart';
import '../widgets/zoom_arc_control.dart' show LocationButton;

/// 地址选择页 —— 顶部地图 + 列表 + 确认按钮。
///
/// 交互（美团 / 淘宝风格）：
/// - Pin 固定在地图视觉正中，pan 地图 → 松手后 reverse-geocode 新中心，
///   列表刷新为新中心附近的 POI，"当前位置"（列表第一项）自动选中。
/// - 点列表某项 → 地图程序化动画到该坐标，radio 打勾；不会触发列表刷新
///   （因 `onCameraIdle` 只在 `MapMoveSource.gesture` 时重算）。
/// - 搜索模式（顶部搜索栏非空）→ 列表切换为搜索结果；点项同上。
/// - 右下角定位按钮 → 回到 `initialLat/Lng` 并刷新。
///
/// 契约：Navigator.pop 返回 [LocationModel]；调用方 `map_page._pickLocation` 零改动。
class LocationPickerPage extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const LocationPickerPage({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Dio _dio = Dio();

  JogyMapController? _mapController;
  bool _mapReady = false;

  /// 当前 pin 所在的地理中心（随用户拖动 / 点选更新）
  late MapLatLng _currentCenter;

  /// idle 前是否有 gesture 移动事件。
  /// 背景：Mapbox 适配器的 `_onMapIdle` 硬编码 source=programmatic，
  /// 无法在 idle 事件本身上区分用户拖动和程序化 moveTo。
  /// 解决方案：在 onCameraMove 里看到 gesture 就置 true，idle 消费后重置。
  bool _hadGestureMove = false;

  List<_PlaceItem> _nearbyPlaces = [];
  List<_PlaceItem> _searchResults = [];
  _PlaceItem? _selected;
  bool _isLoading = true;
  bool _isSearching = false;
  Timer? _debounce;

  /// 并发请求守卫：新请求递增 id，旧请求 callback 对比后丢弃
  int _loadReq = 0;

  bool get _isSearchMode => _searchController.text.trim().isNotEmpty;

  String get _token => MapConfig.mapboxApiKey;

  @override
  void initState() {
    super.initState();
    _currentCenter = MapLatLng(widget.initialLat, widget.initialLng);
    // 让"取消"按钮随 focus 状态显示 / 隐藏
    _searchFocus.addListener(_onFocusChange);
    _loadNearbyPlaces();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocus.removeListener(_onFocusChange);
    _searchFocus.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // 仅触发 rebuild（"取消"按钮依赖 _searchFocus.hasFocus）
    if (mounted) setState(() {});
  }

  void _cancelSearch() {
    _searchFocus.unfocus();
    _searchController.clear();
    _onSearchChanged(''); // 清空搜索结果 + 恢复"当前位置"选中
  }

  // ── Mapbox Tilequery + Geocoding API ────────────────────
  //
  // 附近地点 = 两个 API 并行:
  //   1) Geocoding v5 /reverse  → 拿"当前中心"的可读地址
  //   2) Tilequery /v4/.../poi_label → 半径内周边 POI（有距离排序）
  //
  // 并发守卫：所有 setState 前对比 _loadReq，用户快速拖动时仅最后一次生效。

  Future<void> _loadNearbyPlaces() async {
    final reqId = ++_loadReq;
    final center = _currentCenter;

    final results = await Future.wait([
      _fetchCurrentAddress(center),
      _fetchNearbyPOIs(center),
    ]);
    if (!mounted || reqId != _loadReq) return;

    final currentAddress = results[0] as String;
    final nearbyPOIs = results[1] as List<_PlaceItem>;

    setState(() {
      _nearbyPlaces = [
        // 固定第一项：当前精确位置（= pin 的坐标）
        _PlaceItem(
          name: '当前位置',
          address: currentAddress,
          latitude: center.latitude,
          longitude: center.longitude,
          icon: Icons.my_location,
        ),
        ...nearbyPOIs,
      ];
      _isLoading = false;
      // 默认选中第一项
      _selected = _nearbyPlaces.first;
    });
  }

  Future<String> _fetchCurrentAddress(MapLatLng c) async {
    try {
      final response = await _dio.get(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${c.longitude},${c.latitude}.json',
        queryParameters: {
          'access_token': _token,
          'language': mapboxLanguage(),
          'limit': 1,
          'types': 'address,neighborhood,place',
        },
      );
      final features = response.data['features'] as List? ?? [];
      if (features.isEmpty) return _coordFallback(c);
      return (features.first['place_name'] as String?) ?? _coordFallback(c);
    } catch (_) {
      return _coordFallback(c);
    }
  }

  String _coordFallback(MapLatLng c) =>
      '${c.latitude.toStringAsFixed(6)}, ${c.longitude.toStringAsFixed(6)}';

  Future<List<_PlaceItem>> _fetchNearbyPOIs(MapLatLng c) async {
    try {
      final lang = mapboxLanguage();
      final response = await _dio.get(
        'https://api.mapbox.com/v4/mapbox.mapbox-streets-v8/tilequery/'
        '${c.longitude},${c.latitude}.json',
        queryParameters: {
          'access_token': _token,
          'radius': 500, // 米，Tilequery 硬上限 1000
          'limit': 25, // 硬上限 50
          'layers': 'poi_label',
          'geometry': 'point',
          'dedupe': true,
        },
      );

      final features = response.data['features'] as List? ?? [];
      final items = <_PlaceItem>[];

      for (final f in features) {
        final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? {};
        final coords = f['geometry']?['coordinates'] as List?;
        if (coords == null || coords.length < 2) continue;

        final cls = (props['class'] as String?) ?? '';
        String? pick(String? s) =>
            (s != null && s.trim().isNotEmpty) ? s : null;
        final name = pick(props['name_$lang'] as String?) ??
            pick(props['name'] as String?) ??
            cls;
        if (name.isEmpty) continue;

        items.add(_PlaceItem(
          name: name,
          address: cls,
          latitude: (coords[1] as num).toDouble(),
          longitude: (coords[0] as num).toDouble(),
          icon: Icons.place_outlined,
        ));
      }

      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _searchPlaces(String query) async {
    try {
      final response = await _dio.get(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${Uri.encodeComponent(query)}.json',
        queryParameters: {
          'access_token': _token,
          'proximity': '${_currentCenter.longitude},${_currentCenter.latitude}',
          'language': mapboxLanguage(),
          'limit': 10,
          'types': 'poi,address,place,locality',
        },
      );

      if (!mounted) return;

      final features = response.data['features'] as List? ?? [];
      final results = <_PlaceItem>[];

      for (final feature in features) {
        final coords = feature['geometry']?['coordinates'] as List?;
        if (coords != null && coords.length >= 2) {
          results.add(_PlaceItem(
            name: feature['text'] as String? ?? '',
            address: _extractAddress(feature),
            latitude: (coords[1] as num).toDouble(),
            longitude: (coords[0] as num).toDouble(),
          ));
        }
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  /// 从 Geocoding feature 提取可读地址（去掉最前面的"地点名, "）。
  String _extractAddress(Map<String, dynamic> feature) {
    final placeName = feature['place_name'] as String? ?? '';
    final text = feature['text'] as String? ?? '';
    if (text.isNotEmpty &&
        placeName.startsWith(text) &&
        placeName.length > text.length) {
      return placeName
          .substring(text.length)
          .replaceFirst(RegExp(r'^,\s*'), '');
    }
    return placeName;
  }

  // ── Event handlers ──────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        // 退出搜索模式 → 恢复默认选中"当前位置"
        _selected = _nearbyPlaces.isNotEmpty ? _nearbyPlaces.first : null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      // 进入搜索时清空选中，等用户主动选
      _selected = null;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query.trim());
    });
  }

  void _onCameraMove(MapCameraEvent event) {
    if (event.source == MapMoveSource.gesture) {
      _hadGestureMove = true;
    }
  }

  void _onCameraIdle(MapCameraEvent event) {
    // Mapbox 的 idle 事件 source 总是 programmatic，改用"idle 前是否有 gesture move"
    // 来判断这次 idle 是不是用户拖动造成的。
    final wasGesture = _hadGestureMove;
    _hadGestureMove = false;
    if (!wasGesture) return;

    final newCenter = event.camera.center;
    final distM = _distanceMeters(
      _currentCenter.latitude,
      _currentCenter.longitude,
      newCenter.latitude,
      newCenter.longitude,
    );
    // 小幅抖动忽略（地图 SDK 对"静止"判断有点敏感）
    if (distM < 20) return;

    setState(() {
      _currentCenter = newCenter;
      _isLoading = true;
    });
    _loadNearbyPlaces();
  }

  void _onPlaceTap(_PlaceItem place) {
    final newCenter = MapLatLng(place.latitude, place.longitude);
    setState(() {
      _selected = place;
      _currentCenter = newCenter;
    });
    // 程序化动画（source=animation），不会触发 _onCameraIdle 的重算分支
    _mapController?.moveTo(
      newCenter,
      duration: const Duration(milliseconds: 400),
    );
  }

  void _onRecenter() {
    final initial = MapLatLng(widget.initialLat, widget.initialLng);
    setState(() {
      _currentCenter = initial;
      _isLoading = true;
    });
    _mapController?.moveTo(
      initial,
      duration: const Duration(milliseconds: 400),
    );
    _loadNearbyPlaces();
  }

  void _onConfirm() {
    final s = _selected;
    if (s == null) return;
    Navigator.pop(
      context,
      LocationModel(
        latitude: s.latitude,
        longitude: s.longitude,
        placeName: s.name,
        address: s.address,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────

  /// Haversine 距离（米）
  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // Earth radius in m
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// 距离格式化：< 10km 显示两位小数；≥ 10km 一位；单位 km
  String _formatKm(double meters) {
    final km = meters / 1000;
    if (km < 10) return '${km.toStringAsFixed(2)}km';
    return '${km.toStringAsFixed(1)}km';
  }

  bool _isItemSelected(_PlaceItem item) {
    final s = _selected;
    if (s == null) return false;
    return s.latitude == item.latitude && s.longitude == item.longitude;
  }

  // ── UI ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '地址选择',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          // 键盘弹起时隐藏地图 —— 地图高度按整屏计算，不随 body 压缩，
          // 不隐藏会与 list + 保存按钮挤出 bottom overflow（~几 px 的黄黑警示）。
          // 收起键盘（或点列表里的结果）后自动恢复。
          if (MediaQuery.of(context).viewInsets.bottom == 0) _buildMapSection(),
          Expanded(child: _buildList()),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final focused = _searchFocus.hasFocus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '搜索地标',
                        hintStyle:
                            TextStyle(color: Colors.grey[400], fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: Icon(
                        Icons.cancel,
                        size: 18,
                        color: Colors.grey[400],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 右侧"取消"按钮：仅在搜索框聚焦时显示。点它会收键盘 + 清文字 +
          // 回到"附近地点"模式，相当于一键退出搜索。
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: focused
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _cancelSearch,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF3FAAF0),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    final mediaHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: mediaHeight * 0.32, // ~32% 视口高度
      child: Stack(
        children: [
          MapboxMapWidgetBuilder(
            styleUri: MapConfig.mapboxStyleUri,
          ).build(JogyMapOptions(
            initialCenter: MapLatLng(widget.initialLat, widget.initialLng),
            initialZoom: 16.5,
            initialPitch: 0,
            rotationEnabled: false,
            pitchEnabled: false,
            followHeadingOnStart: false,
            onMapCreated: (controller) {
              setState(() {
                _mapController = controller;
                _mapReady = true;
              });
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          )),
          // 固定在视觉正中的 pin（不吃手势，pan 由地图接管）
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: const Offset(0, -20), // 让 pin 尖部指向中心
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF1F1F1F),
                  size: 44,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 右下角定位按钮
          if (_mapReady)
            Positioned(
              right: 12,
              bottom: 12,
              child: LocationButton(onTap: _onRecenter),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // 初次加载
    if (_isLoading && _nearbyPlaces.isEmpty && !_isSearchMode) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isSearchMode) {
      if (_isSearching) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_searchResults.isEmpty) {
        return _buildEmptyState('没有找到相关地点');
      }
      return _buildPlaceList(_searchResults);
    }

    if (_nearbyPlaces.isEmpty) {
      return _buildEmptyState('附近没有可用地点');
    }
    return _buildPlaceList(_nearbyPlaces);
  }

  Widget _buildPlaceList(List<_PlaceItem> places) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: places.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 50,
        endIndent: 16,
        color: Colors.grey[200],
      ),
      itemBuilder: (context, index) => _buildPlaceItem(places[index]),
    );
  }

  Widget _buildPlaceItem(_PlaceItem place) {
    final selected = _isItemSelected(place);
    // 距离基准固定为打开本页时的实时定位 (initialLat/Lng)，
    // 不随 pin / _currentCenter 移动而变化，保持每项距离稳定。
    final distMeters = _distanceMeters(
      widget.initialLat,
      widget.initialLng,
      place.latitude,
      place.longitude,
    );

    return InkWell(
      onTap: () => _onPlaceTap(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _RadioMark(selected: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      place.address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatKm(distMeters),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final enabled = _selected != null;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: enabled ? _onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3FAAF0),
            disabledBackgroundColor: Colors.grey[200],
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.grey[400],
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: const Text(
            '确认选择',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// 圆形勾选标记（代替 Flutter 自带的 Radio，样式更贴合截图）
class _RadioMark extends StatelessWidget {
  final bool selected;
  const _RadioMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFF3FAAF0) : Colors.grey[400]!,
          width: 2,
        ),
        color: selected ? const Color(0xFF3FAAF0) : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

/// 内部地点数据模型
class _PlaceItem {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final IconData icon;

  const _PlaceItem({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.icon = Icons.location_on_outlined,
  });
}
