import 'dart:math' as math;
import '../../domain/repositories/post_repository.dart';
import '../models/post_model.dart';
import '../datasources/mock_data_source.dart';

class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl();

  @override
  Future<List<PostModel>> getPosts() async {
    return await MockDataSource.fetchPosts();
  }

  @override
  Future<PostModel?> getPostById(String id) async {
    return await MockDataSource.getPostById(id);
  }

  @override
  Future<List<PostModel>> getPostsByLocation({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
  }) async {
    // 模拟根据位置获取帖子（暂时直接返回所有帖子）
    return await MockDataSource.fetchPosts();
  }

  @override
  Future<List<PostModel>> getPostsByBounds({
    required double minLatitude,
    required double minLongitude,
    required double maxLatitude,
    required double maxLongitude,
  }) async {
    // Mock 阶段：使用 MockDataSource 过滤
    // 后端阶段：切换到 RemoteDataSource.fetchDiscoverPosts()
    return await MockDataSource.fetchPostsByBounds(
      minLatitude: minLatitude,
      minLongitude: minLongitude,
      maxLatitude: maxLatitude,
      maxLongitude: maxLongitude,
    );
  }

  // Calculate distance between two points in kilometers using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth's radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
