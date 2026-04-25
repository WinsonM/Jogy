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

      _isLoading = false;
      notifyListeners();
    } catch (e) {
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
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // 静默失败，保留当前 posts
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
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final post = _posts[postIndex];
      _posts[postIndex] = post.copyWith(
        isLiked: !post.isLiked,
        likes: post.isLiked ? post.likes - 1 : post.likes + 1,
      );
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String postId) async {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final post = _posts[postIndex];
      _posts[postIndex] = post.copyWith(
        isFavorited: !post.isFavorited,
        favorites: post.isFavorited ? post.favorites - 1 : post.favorites + 1,
      );
      notifyListeners();
    }
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
