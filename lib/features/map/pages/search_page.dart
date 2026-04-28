import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config/map_config.dart';
import '../../../core/map/map_types.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/user_model.dart';
import '../../../utils/mapbox_language.dart';
import '../../profile/profile_navigation.dart';

class SearchPage extends StatefulWidget {
  final MapLatLng? proximity;

  const SearchPage({super.key, this.proximity});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class MapPlaceSearchResult {
  final String name;
  final String address;
  final MapLatLng coordinate;

  const MapPlaceSearchResult({
    required this.name,
    required this.address,
    required this.coordinate,
  });
}

class _GlobalSearchResults {
  final List<PostModel> posts;
  final List<UserModel> users;

  const _GlobalSearchResults({required this.posts, required this.users});
}

class _SearchPageState extends State<SearchPage> {
  static const int _maxResultsPerSection = 4;
  static const int _maxSearchHistory = 5;
  static const String _searchHistoryKey = 'homepage_search_history';

  final RemoteDataSource _remote = RemoteDataSource();
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<PostModel> _postResults = [];
  List<UserModel> _userResults = [];
  List<MapPlaceSearchResult> _placeResults = [];
  List<String> _searchHistory = [];
  bool _isLoading = false;
  bool _hasSearched = false; // true after first search completes
  int _searchReq = 0;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final reqId = ++_searchReq;

    if (query.trim().isEmpty) {
      setState(() {
        _postResults = [];
        _userResults = [];
        _placeResults = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = false;
      _postResults = [];
      _userResults = [];
      _placeResults = [];
    });

    // 500ms debounce
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _doSearch(query.trim(), reqId);
    });
  }

  Future<void> _doSearch(String query, int reqId) async {
    if (!mounted) return;
    if (reqId != _searchReq) return;
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _searchBackend(query),
      _searchMapboxPlaces(query),
    ]);

    if (!mounted || reqId != _searchReq) return;

    final globalResults = results[0] as _GlobalSearchResults;
    final placeResults = results[1] as List<MapPlaceSearchResult>;

    setState(() {
      _postResults = globalResults.posts;
      _userResults = globalResults.users;
      _placeResults = placeResults;
      _isLoading = false;
      _hasSearched = true;
    });
  }

  Future<_GlobalSearchResults> _searchBackend(String query) async {
    try {
      final data = await _remote.searchGlobal(query);
      final posts =
          (data['posts'] as List?)
              ?.map((json) => PostModel.fromJson(json as Map<String, dynamic>))
              .take(_maxResultsPerSection)
              .toList() ??
          [];
      final users =
          (data['users'] as List?)
              ?.map((json) => UserModel.fromJson(json as Map<String, dynamic>))
              .take(_maxResultsPerSection)
              .toList() ??
          [];

      return _GlobalSearchResults(posts: posts, users: users);
    } catch (_) {
      return const _GlobalSearchResults(posts: [], users: []);
    }
  }

  Future<List<MapPlaceSearchResult>> _searchMapboxPlaces(String query) async {
    final token = MapConfig.mapboxApiKey;
    if (token.isEmpty) return [];

    try {
      final proximity = widget.proximity;
      final response = await _dio.get(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${Uri.encodeComponent(query)}.json',
        queryParameters: {
          'access_token': token,
          if (proximity != null)
            'proximity': '${proximity.longitude},${proximity.latitude}',
          'language': mapboxLanguage(),
          'limit': _maxResultsPerSection,
          'types': 'poi,address,place,locality,neighborhood',
        },
      );

      final features = response.data['features'] as List? ?? [];
      final results = <MapPlaceSearchResult>[];

      for (final rawFeature in features) {
        if (rawFeature is! Map) continue;
        final feature = rawFeature.cast<String, dynamic>();
        final coords = feature['geometry']?['coordinates'] as List?;
        if (coords == null || coords.length < 2) continue;

        final name = (feature['text'] as String? ?? '').trim();
        if (name.isEmpty) continue;

        results.add(
          MapPlaceSearchResult(
            name: name,
            address: _extractAddress(feature),
            coordinate: MapLatLng(
              (coords[1] as num).toDouble(),
              (coords[0] as num).toDouble(),
            ),
          ),
        );

        if (results.length >= _maxResultsPerSection) break;
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  String _extractAddress(Map<String, dynamic> feature) {
    final text = feature['text'] as String? ?? '';
    final placeName = feature['place_name'] as String? ?? '';
    if (text.isNotEmpty &&
        placeName.startsWith(text) &&
        placeName.length > text.length) {
      return placeName
          .substring(text.length)
          .replaceFirst(RegExp(r'^,\s*'), '');
    }
    return placeName;
  }

  Future<void> _loadSearchHistory() async {
    try {
      final encoded = await _storage.read(key: _searchHistoryKey);
      if (encoded == null || encoded.isEmpty) return;
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return;

      final items = decoded
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(_maxSearchHistory)
          .toList();

      if (!mounted) return;
      setState(() => _searchHistory = items);
    } catch (_) {
      // Search history is optional; ignore corrupted local data.
    }
  }

  Future<void> _saveSearchHistory([String? value]) async {
    final query = (value ?? _searchController.text).trim();
    if (query.isEmpty) return;

    final normalized = query.toLowerCase();
    final next = <String>[
      query,
      ..._searchHistory.where(
        (item) => item.trim().toLowerCase() != normalized,
      ),
    ].take(_maxSearchHistory).toList();

    if (mounted) {
      setState(() => _searchHistory = next);
    } else {
      _searchHistory = next;
    }

    try {
      await _storage.write(key: _searchHistoryKey, value: jsonEncode(next));
    } catch (_) {
      // Search history should never block navigation.
    }
  }

  Future<void> _clearSearchHistory() async {
    try {
      await _storage.delete(key: _searchHistoryKey);
    } catch (_) {
      // Local history is optional.
    }
    if (!mounted) return;
    setState(() => _searchHistory = []);
  }

  void _onHistoryTap(String query) {
    _debounce?.cancel();
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    final reqId = ++_searchReq;
    _doSearch(query, reqId);
  }

  Future<void> _submitSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    await _saveSearchHistory(normalized);
    final reqId = ++_searchReq;
    await _doSearch(normalized, reqId);
  }

  void _onPostTap(PostModel post) {
    unawaited(_saveSearchHistory());
    Navigator.pop(context, post);
  }

  void _onPlaceTap(MapPlaceSearchResult place) {
    unawaited(_saveSearchHistory());
    Navigator.pop(context, place);
  }

  void _onUserTap(UserModel user) {
    unawaited(_saveSearchHistory());
    openUserProfile(
      context,
      userId: user.id,
      userName: user.username,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      gender: user.gender,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Search bar
          Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 22, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            onChanged: _onSearchChanged,
                            onSubmitted: _submitSearch,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: '搜索帖子、用户或地点',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Results
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_searchController.text.isEmpty) return _buildHistoryOrEmptyHint();
    if (_isLoading) return _buildLoading();
    if (_hasSearched &&
        _placeResults.isEmpty &&
        _userResults.isEmpty &&
        _postResults.isEmpty) {
      return _buildNoResults();
    }
    return _buildResultsList();
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '输入关键词搜索',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryOrEmptyHint() {
    if (_searchHistory.isEmpty) return _buildEmptyHint();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearSearchHistory,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 32),
                ),
                child: const Text('清除'),
              ),
            ],
          ),
        ),
        ..._searchHistory.map(_buildHistoryItem),
      ],
    );
  }

  Widget _buildHistoryItem(String query) {
    return GestureDetector(
      onTap: () => _onHistoryTap(query),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.history, size: 20, color: Colors.grey[500]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '没有找到相关结果',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Places section
        if (_placeResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '地点',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          ..._placeResults.map(_buildPlaceItem),
          if (_userResults.isNotEmpty || _postResults.isNotEmpty)
            const Divider(height: 24, indent: 16, endIndent: 16),
        ],
        // Users section
        if (_userResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '用户',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          ..._userResults.map(_buildUserItem),
          if (_postResults.isNotEmpty)
            const Divider(height: 24, indent: 16, endIndent: 16),
        ],
        // Posts section
        if (_postResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '帖子',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          ..._postResults.map(_buildPostItem),
        ],
      ],
    );
  }

  Widget _buildPlaceItem(MapPlaceSearchResult place) {
    return GestureDetector(
      onTap: () => _onPlaceTap(place),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5FE),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: Color(0xFF3FAAF0),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(UserModel user) {
    return GestureDetector(
      onTap: () => _onUserTap(user),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[300],
              backgroundImage: user.avatarUrl.isNotEmpty
                  ? NetworkImage(user.avatarUrl)
                  : null,
              child: user.avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 20, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildPostItem(PostModel post) {
    return GestureDetector(
      onTap: () => _onPostTap(post),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[200],
              backgroundImage: post.user.avatarUrl.isNotEmpty
                  ? NetworkImage(post.user.avatarUrl)
                  : null,
              child: post.user.avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 20, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.user.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  if (post.location.placeName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            post.location.placeName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (post.imageUrls.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrls.first,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
