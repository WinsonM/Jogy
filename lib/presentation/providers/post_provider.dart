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
}
