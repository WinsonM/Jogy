import '../../data/models/post_model.dart';

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
}
