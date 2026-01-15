import 'dart:math' as math;
import '../../domain/repositories/post_repository.dart';
import '../models/post_model.dart';
import '../datasources/mock_data_source.dart';

class PostRepositoryImpl implements PostRepository {
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
    final allPosts = await getPosts();

    // Filter posts within radius using Haversine formula
    return allPosts.where((post) {
      final distance = _calculateDistance(
        latitude,
        longitude,
        post.location.latitude,
        post.location.longitude,
      );
      return distance <= radiusInKm;
    }).toList();
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
