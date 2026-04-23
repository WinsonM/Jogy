import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../config/map_config.dart';
import '../../../data/models/location_model.dart';

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
  // 独立 Dio 实例，不带业务 auth header
  final Dio _dio = Dio();

  List<_PlaceItem> _nearbyPlaces = [];
  List<_PlaceItem> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  Timer? _debounce;

  String get _token => MapConfig.mapboxApiKey;

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaces();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Mapbox Geocoding v5 API ─────────────────────────────

  /// 反向地理编码：根据当前坐标获取附近地点
  Future<void> _loadNearbyPlaces() async {
    try {
      final response = await _dio.get(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${widget.initialLng},${widget.initialLat}.json',
        queryParameters: {
          'access_token': _token,
          'language': 'zh',
          'limit': 5,
        },
      );

      if (!mounted) return;

      final features = response.data['features'] as List? ?? [];

      final places = <_PlaceItem>[
        // 固定第一项：当前精确位置
        _PlaceItem(
          name: '当前位置',
          address: features.isNotEmpty
              ? _extractAddress(features.first)
              : '${widget.initialLat.toStringAsFixed(6)}, '
                  '${widget.initialLng.toStringAsFixed(6)}',
          latitude: widget.initialLat,
          longitude: widget.initialLng,
          icon: Icons.my_location,
        ),
      ];

      // 将反向编码结果加入列表
      for (final feature in features) {
        final coords = feature['geometry']?['coordinates'] as List?;
        if (coords != null && coords.length >= 2) {
          places.add(_PlaceItem(
            name: feature['text'] as String? ?? '',
            address: _extractAddress(feature),
            latitude: (coords[1] as num).toDouble(),
            longitude: (coords[0] as num).toDouble(),
          ));
        }
      }

      setState(() {
        _nearbyPlaces = places;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // 即使 API 失败也保留"当前位置"可选
      setState(() {
        _nearbyPlaces = [
          _PlaceItem(
            name: '当前位置',
            address: '${widget.initialLat.toStringAsFixed(6)}, '
                '${widget.initialLng.toStringAsFixed(6)}',
            latitude: widget.initialLat,
            longitude: widget.initialLng,
            icon: Icons.my_location,
          ),
        ];
        _isLoading = false;
      });
    }
  }

  /// 正向地理编码：根据搜索关键词查找地点（proximity 偏向当前位置）
  Future<void> _searchPlaces(String query) async {
    try {
      final response = await _dio.get(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${Uri.encodeComponent(query)}.json',
        queryParameters: {
          'access_token': _token,
          'proximity': '${widget.initialLng},${widget.initialLat}',
          'language': 'zh',
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

  /// 从 Geocoding feature 中提取可读地址
  /// place_name 格式为 "地点名, 区, 市, 省, 国"，去掉第一段得到纯地址
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
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query.trim());
    });
  }

  void _onPlaceSelected(_PlaceItem place) {
    Navigator.pop(
      context,
      LocationModel(
        latitude: place.latitude,
        longitude: place.longitude,
        placeName: place.name,
        address: place.address,
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('选择位置', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: Colors.grey[500]),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: '搜索地点',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
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
                child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // 搜索模式
    if (_searchController.text.isNotEmpty) {
      if (_isSearching) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_searchResults.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                '没有找到相关地点',
                style: TextStyle(color: Colors.grey[500], fontSize: 15),
              ),
            ],
          ),
        );
      }
      return _buildPlaceList(_searchResults);
    }

    // 默认：显示附近地点
    return _buildPlaceList(_nearbyPlaces);
  }

  Widget _buildPlaceList(List<_PlaceItem> places) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: places.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 60, endIndent: 16),
      itemBuilder: (context, index) => _buildPlaceItem(places[index]),
    );
  }

  Widget _buildPlaceItem(_PlaceItem place) {
    return InkWell(
      onTap: () => _onPlaceSelected(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(place.icon, size: 20, color: Colors.grey[600]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      place.address,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
