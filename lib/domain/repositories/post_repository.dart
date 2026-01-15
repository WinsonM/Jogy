import '../../data/models/post_model.dart';

abstract class PostRepository {
  Future<List<PostModel>> getPosts();
  Future<PostModel?> getPostById(String id);
  Future<List<PostModel>> getPostsByLocation({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
  });
}
