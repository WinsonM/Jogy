import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';

abstract class PostRepository {
  Future<List<PostModel>> getPosts();
  Future<PostModel?> getPostById(String id);
  Future<List<PostModel>> getPostsByLocation({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
  });

  /// 根据可视范围获取帖子（用于地图视口刷新）
  Future<List<PostModel>> getPostsByBounds({
    required double minLatitude,
    required double minLongitude,
    required double maxLatitude,
    required double maxLongitude,
  });

  Future<Map<String, dynamic>> toggleLikePost(String postId);

  Future<Map<String, dynamic>> toggleFavoritePost(String postId);

  Future<CommentModel> createComment(
    String postId, {
    required String content,
    String? parentId,
    String? replyToUserId,
  });
}
