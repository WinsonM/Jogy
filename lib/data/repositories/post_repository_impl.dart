import 'dart:math' as math;
import '../../domain/repositories/post_repository.dart';
import '../models/post_model.dart';
import '../datasources/mock_data_source.dart';
import '../datasources/remote_data_source.dart';

class PostRepositoryImpl implements PostRepository {
  final RemoteDataSource _remoteDataSource;

  PostRepositoryImpl({RemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? RemoteDataSource();

  @override
  Future<List<PostModel>> getPosts() async {
    // Fallback to mock data for now
    return await MockDataSource.fetchPosts();
  }

  @override
  Future<PostModel?> getPostById(String id) async {
    try {
      return await _remoteDataSource.fetchPostById(id);
    } catch (e) {
      // Fallback to mock data if backend is unreachable
      return await MockDataSource.getPostById(id);
    }
  }

  @override
  Future<List<PostModel>> getPostsByLocation({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
  }) async {
    // Convert radius to approximate bounding box
    final latDelta = radiusInKm / 111.0; // ~111km per degree latitude
    final lngDelta =
        radiusInKm / (111.0 * math.cos(latitude * math.pi / 180));

    try {
      return await getPostsByBounds(
        minLatitude: latitude - latDelta,
        minLongitude: longitude - lngDelta,
        maxLatitude: latitude + latDelta,
        maxLongitude: longitude + lngDelta,
      );
    } catch (e) {
      // Fallback to mock data
      return await MockDataSource.fetchPosts();
    }
  }

  @override
  Future<List<PostModel>> getPostsByBounds({
    required double minLatitude,
    required double minLongitude,
    required double maxLatitude,
    required double maxLongitude,
  }) async {
    try {
      final response = await _remoteDataSource.fetchDiscoverPosts(
        minLatitude: minLatitude,
        minLongitude: minLongitude,
        maxLatitude: maxLatitude,
        maxLongitude: maxLongitude,
      );

      final postsJson = response['posts'] as List<dynamic>? ?? [];
      return postsJson
          .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback to mock data if backend is unreachable
      return await MockDataSource.fetchPostsByBounds(
        minLatitude: minLatitude,
        minLongitude: minLongitude,
        maxLatitude: maxLatitude,
        maxLongitude: maxLongitude,
      );
    }
  }
}
