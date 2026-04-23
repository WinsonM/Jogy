import 'package:flutter/foundation.dart';
import '../../domain/repositories/post_repository.dart';
import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';

class PostProvider extends ChangeNotifier {
  final PostRepository _repository;

  PostProvider(this._repository);

  List<PostModel> _posts = [];
  List<PostModel> get posts => _posts;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> fetchPosts() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _posts = await _repository.getPosts();

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

      _posts = await _repository.getPostsByLocation(
        latitude: latitude,
        longitude: longitude,
        radiusInKm: radiusInKm,
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

      _posts = newPosts;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // 静默失败，保留当前 posts
    }
  }

  /// Insert a newly created post at the top of the list and notify listeners.
  void addNewPost(PostModel post) {
    _posts.insert(0, post);
    notifyListeners();
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
