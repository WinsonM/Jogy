import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import '../../domain/repositories/post_repository.dart';
import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';

class PostProvider extends ChangeNotifier {
  final PostRepository _repository;

  PostProvider(this._repository);

  List<PostModel> _posts = [];
  List<PostModel> get posts => _posts;

  String? _lastRemovedPostId;
  String? get lastRemovedPostId => _lastRemovedPostId;

  int _engagementChangeVersion = 0;
  PostEngagementChange? _lastEngagementChange;
  PostEngagementChange? get lastEngagementChange => _lastEngagementChange;

  final Set<String> _pendingLikeToggles = {};
  final Set<String> _pendingFavoriteToggles = {};

  /// 最近通过 [addNewPost] 本地插入的 post：id -> (post, addedAt)。
  ///
  /// 每次 fetch 类操作收到远端结果时由 [_mergeLocalAdditions] 处理：
  ///  - TTL 过期（[_localAdditionTtl]）→ 清掉；
  ///  - 远端已包含该 id → 远端是权威，清掉；
  ///  - 否则按 scope（bounds/radius）判断是否拼回结果前面。
  ///
  /// 用 `Map<id, entry>` 而非纯 id `Set`，是因为 helper 不能依赖
  /// 当前 [_posts] 仍然包含该 post（万一其他路径清空了 _posts 就找不回）。
  final Map<String, _LocalPostEntry> _localAdditions = {};

  /// 本地副本最长保留时长。超过即清理：
  /// 避免后端永远不再返回的 post（被删 / 审核拒 / 复制故障）变成会话内"幽灵"。
  static const Duration _localAdditionTtl = Duration(minutes: 2);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> fetchPosts() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 全量加载没有作用域，pending 一律拼回；远端已含的 pending 也会被
      // helper 自动清掉，不会重复显示。
      _posts = _mergeLocalAdditions(await _repository.getPosts());

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 根据位置获取帖子（用于初次定位后加载）
  Future<void> fetchPostsByLocation({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
  }) async {
    try {
      _isLoading = _posts.isEmpty; // 仅首次加载时显示 loading
      _error = null;
      if (_isLoading) notifyListeners();

      final remote = await _repository.getPostsByLocation(
        latitude: latitude,
        longitude: longitude,
        radiusInKm: radiusInKm,
      );

      // 仅把仍落在请求 radius 内的本地 pending 拼回，避免发布后把地图
      // 移到很远处仍混入远处 post（参见 [_mergeLocalAdditions]）。
      _posts = _mergeLocalAdditions(
        remote,
        withinScope: (p) {
          final dKm = _approxDistanceKm(
            latitude,
            longitude,
            p.location.latitude,
            p.location.longitude,
          );
          return dKm <= radiusInKm;
        },
      );
      debugPrint(
        '[PostProvider] fetchPostsByLocation lat=$latitude lng=$longitude '
        'r=${radiusInKm}km remote=${remote.length} _posts=${_posts.length}',
      );

      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[PostProvider] fetchPostsByLocation FAILED: $e\n$st');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 根据可视范围获取帖子（用于地图滑动后刷新）
  Future<void> fetchPostsByBounds({
    required double minLatitude,
    required double minLongitude,
    required double maxLatitude,
    required double maxLongitude,
  }) async {
    try {
      _error = null;
      // 不设 _isLoading，避免地图被销毁重建

      final newPosts = await _repository.getPostsByBounds(
        minLatitude: minLatitude,
        minLongitude: minLongitude,
        maxLatitude: maxLatitude,
        maxLongitude: maxLongitude,
      );

      // 仅把仍落在请求 bounds 内的本地 pending 拼回。padding ~0.001° ≈ 111m，
      // 防止坐标恰好压在边界时本地 post 在 fetch 间闪烁。
      const pad = 0.001;
      _posts = _mergeLocalAdditions(
        newPosts,
        withinScope: (p) {
          final lat = p.location.latitude;
          final lng = p.location.longitude;
          return lat >= minLatitude - pad &&
              lat <= maxLatitude + pad &&
              lng >= minLongitude - pad &&
              lng <= maxLongitude + pad;
        },
      );
      debugPrint(
        '[PostProvider] fetchPostsByBounds remote=${newPosts.length} '
        'localPool=${_localAdditions.length} _posts=${_posts.length}',
      );
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      // 之前是完全静默失败，导致 discover 出 5xx 时前端整页空白且无任何提示。
      debugPrint('[PostProvider] fetchPostsByBounds FAILED: $e\n$st');
    }
  }

  /// Insert a newly created post at the top of the list and notify listeners.
  ///
  /// 使用 upsert 语义：同 id 已存在时先 remove 再 insert，避免重复回调 / 重试 /
  /// 未来 WebSocket 推回自己刚发的 post 时堆叠出多个气泡。
  ///
  /// 同时记入 [_localAdditions]，让任何后续 fetch 走 [_mergeLocalAdditions]
  /// 的覆写都不会把这个本地副本抹掉，直到：
  ///  (a) 远端 fetch 的结果里出现该 id（远端权威，本地清掉），或
  ///  (b) 超过 [_localAdditionTtl]（自动清理，避免幽灵）。
  void addNewPost(PostModel post) {
    _posts.removeWhere((p) => p.id == post.id);
    _posts.insert(0, post);
    _localAdditions[post.id] = _LocalPostEntry(post, DateTime.now());
    debugPrint(
      '[PostProvider] addNewPost id=${post.id}, '
      'location=${post.location.latitude},${post.location.longitude}, '
      'count=${_posts.length}',
    );
    notifyListeners();
  }

  /// Remove a post by id (call after successful DELETE on backend).
  /// Also clears any pending local-only copy so it won't be re-added by
  /// [_mergeLocalAdditions] on the next fetch.
  void removePost(String postId) {
    final before = _posts.length;
    _posts.removeWhere((p) => p.id == postId);
    _localAdditions.remove(postId);
    _lastRemovedPostId = postId;
    debugPrint(
      '[PostProvider] removePost id=$postId removed=${before - _posts.length}',
    );
    notifyListeners();
  }

  /// Replace an existing post in-place by id (call after successful PATCH).
  /// Preserves list order — important for the home map renderer that uses
  /// posts[0] as a stable anchor.
  void updatePost(PostModel updated) {
    final i = _posts.indexWhere((p) => p.id == updated.id);
    if (i == -1) {
      // Post 不在当前列表（可能被 fetchPostsByBounds 移出视口）。仅当本地
      // pending 池里有时同步刷新；否则忽略 — 下次 fetch 自然带回。
      if (_localAdditions.containsKey(updated.id)) {
        _localAdditions[updated.id] = _LocalPostEntry(updated, DateTime.now());
        notifyListeners();
      }
      return;
    }
    _posts[i] = updated;
    if (_localAdditions.containsKey(updated.id)) {
      _localAdditions[updated.id] = _LocalPostEntry(updated, DateTime.now());
    }
    debugPrint('[PostProvider] updatePost id=${updated.id} idx=$i');
    notifyListeners();
  }

  // ── Local-additions merge ───────────────────────────────────────────
  //
  // 解决"刚 addNewPost 的 post 在下一次 fetchPostsByBounds 全量覆写时被抹掉"
  // 的 race。详见 [_localAdditions] 文档与 plan 文件。

  /// 把仍未被远端纳入的本地 pending post 拼回 [remote] 前面。
  ///
  /// [withinScope]：可选作用域过滤器。当本次 fetch 是 bounds 或 radius 限定时，
  /// 只把仍落在当前作用域内的 pending 拼回，避免发布后把地图 pan 到很远处
  /// 仍混入刚发的远处 post。`null` 表示全量场景（[fetchPosts]），不过滤。
  List<PostModel> _mergeLocalAdditions(
    List<PostModel> remote, {
    bool Function(PostModel post)? withinScope,
  }) {
    if (_localAdditions.isEmpty) return remote;

    // 1. TTL 清理（在任何 fetch 路径上自动 self-heal，无需 Timer）
    final now = DateTime.now();
    _localAdditions.removeWhere(
      (_, e) => now.difference(e.addedAt) > _localAdditionTtl,
    );
    if (_localAdditions.isEmpty) return remote;

    // 2. 远端已知的 id：远端权威，清掉
    final remoteIds = remote.map((p) => p.id).toSet();
    _localAdditions.removeWhere((id, _) => remoteIds.contains(id));
    if (_localAdditions.isEmpty) return remote;

    // 3. 剩下的 pending 按 scope 过滤后拼回前面
    final pending = <PostModel>[];
    for (final entry in _localAdditions.values) {
      if (withinScope != null && !withinScope(entry.post)) continue;
      pending.add(entry.post);
    }
    if (pending.isEmpty) return remote;

    return [...pending, ...remote];
  }

  /// 近似 Haversine（米→km）。仅用于 [_mergeLocalAdditions] 的 radius 过滤，
  /// 不参与业务展示，所以精度只要够区分"是否在 radiusInKm 内"即可。
  double _approxDistanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Future<PostModel?> getPostById(String id) async {
    try {
      return await _repository.getPostById(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> toggleLike(String postId) async {
    if (!_pendingLikeToggles.add(postId)) return;

    final original = _findPost(postId);
    if (original == null) {
      _pendingLikeToggles.remove(postId);
      return;
    }

    final optimistic = original.copyWith(
      isLiked: !original.isLiked,
      likes: math.max(0, original.likes + (original.isLiked ? -1 : 1)),
    );
    _replacePostEverywhere(optimistic);
    _publishEngagementChange(optimistic, isLiked: optimistic.isLiked);
    notifyListeners();

    try {
      final response = await _repository.toggleLikePost(postId);
      final confirmed = optimistic.copyWith(
        isLiked: _boolFromResponse(response, const [
          'liked',
          'isLiked',
        ], fallback: optimistic.isLiked),
      );
      _replacePostEverywhere(confirmed);
      _publishEngagementChange(confirmed, isLiked: confirmed.isLiked);
      _error = null;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[PostProvider] toggleLike FAILED id=$postId: $e\n$st');
      _replacePostEverywhere(original);
      _publishEngagementChange(original, isLiked: original.isLiked);
      _error = e.toString();
      notifyListeners();
    } finally {
      _pendingLikeToggles.remove(postId);
    }
  }

  Future<void> toggleFavorite(String postId) async {
    if (!_pendingFavoriteToggles.add(postId)) return;

    final original = _findPost(postId);
    if (original == null) {
      _pendingFavoriteToggles.remove(postId);
      return;
    }

    final optimistic = original.copyWith(
      isFavorited: !original.isFavorited,
      favorites: math.max(
        0,
        original.favorites + (original.isFavorited ? -1 : 1),
      ),
    );
    _replacePostEverywhere(optimistic);
    _publishEngagementChange(optimistic, isFavorited: optimistic.isFavorited);
    notifyListeners();

    try {
      final response = await _repository.toggleFavoritePost(postId);
      final confirmed = optimistic.copyWith(
        isFavorited: _boolFromResponse(response, const [
          'favorited',
          'isFavorited',
        ], fallback: optimistic.isFavorited),
      );
      _replacePostEverywhere(confirmed);
      _publishEngagementChange(confirmed, isFavorited: confirmed.isFavorited);
      _error = null;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[PostProvider] toggleFavorite FAILED id=$postId: $e\n$st');
      _replacePostEverywhere(original);
      _publishEngagementChange(original, isFavorited: original.isFavorited);
      _error = e.toString();
      notifyListeners();
    } finally {
      _pendingFavoriteToggles.remove(postId);
    }
  }

  PostModel? _findPost(String postId) {
    for (final post in _posts) {
      if (post.id == postId) return post;
    }
    return _localAdditions[postId]?.post;
  }

  void _replacePostEverywhere(PostModel updated) {
    for (var i = 0; i < _posts.length; i++) {
      if (_posts[i].id == updated.id) {
        _posts[i] = updated;
      }
    }
    if (_localAdditions.containsKey(updated.id)) {
      _localAdditions[updated.id] = _LocalPostEntry(updated, DateTime.now());
    }
  }

  void _publishEngagementChange(
    PostModel post, {
    bool? isLiked,
    bool? isFavorited,
  }) {
    _engagementChangeVersion++;
    _lastEngagementChange = PostEngagementChange(
      version: _engagementChangeVersion,
      post: post,
      isLiked: isLiked,
      isFavorited: isFavorited,
    );
  }

  bool _boolFromResponse(
    Map<String, dynamic> response,
    List<String> keys, {
    required bool fallback,
  }) {
    for (final key in keys) {
      final value = response[key];
      if (value is bool) return value;
    }
    return fallback;
  }

  Future<void> toggleCommentLike(String postId, String commentId) async {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final post = _posts[postIndex];
      final commentIndex = post.comments.indexWhere((c) => c.id == commentId);

      if (commentIndex != -1) {
        final comment = post.comments[commentIndex];
        final updatedComments = List<CommentModel>.from(post.comments);
        updatedComments[commentIndex] = comment.copyWith(
          isLiked: !comment.isLiked,
          likes: comment.isLiked ? comment.likes - 1 : comment.likes + 1,
        );

        _posts[postIndex] = post.copyWith(comments: updatedComments);
        notifyListeners();
      }
    }
  }

  /// 搜索帖子 - 匹配内容、用户名、地点名称或地址
  List<PostModel> searchPosts(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _posts.where((post) {
      return post.content.toLowerCase().contains(lowerQuery) ||
          post.user.username.toLowerCase().contains(lowerQuery) ||
          (post.location.placeName?.toLowerCase().contains(lowerQuery) ??
              false) ||
          (post.location.address?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}

/// 本地新增 post 的内部记录：保留 PostModel 副本 + 入栈时间，
/// 让 [PostProvider._mergeLocalAdditions] 不依赖 [PostProvider._posts]
/// 当前是否仍包含该 post，且能基于 [DateTime] 做 TTL 清理。
class _LocalPostEntry {
  final PostModel post;
  final DateTime addedAt;
  const _LocalPostEntry(this.post, this.addedAt);
}

class PostEngagementChange {
  final int version;
  final PostModel post;
  final bool? isLiked;
  final bool? isFavorited;

  const PostEngagementChange({
    required this.version,
    required this.post,
    this.isLiked,
    this.isFavorited,
  });
}
