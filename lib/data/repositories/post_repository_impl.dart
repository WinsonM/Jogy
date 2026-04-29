import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../domain/repositories/post_repository.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../datasources/remote_data_source.dart';

class PostRepositoryImpl implements PostRepository {
  final RemoteDataSource _remoteDataSource;

  PostRepositoryImpl({RemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? RemoteDataSource();

  @override
  Future<List<PostModel>> getPosts() async {
    // 主要通过 getPostsByLocation / getPostsByBounds 获取帖子
    return [];
  }

  @override
  Future<PostModel?> getPostById(String id) async {
    return await _remoteDataSource.fetchPostById(id);
  }

  @override
  Future<List<PostModel>> getPostsByLocation({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
  }) async {
    // Convert radius to approximate bounding box
    final latDelta = radiusInKm / 111.0; // ~111km per degree latitude
    final lngDelta = radiusInKm / (111.0 * math.cos(latitude * math.pi / 180));

    return await getPostsByBounds(
      minLatitude: latitude - latDelta,
      minLongitude: longitude - lngDelta,
      maxLatitude: latitude + latDelta,
      maxLongitude: longitude + lngDelta,
    );
  }

  @override
  Future<List<PostModel>> getPostsByBounds({
    required double minLatitude,
    required double minLongitude,
    required double maxLatitude,
    required double maxLongitude,
  }) async {
    final response = await _remoteDataSource.fetchDiscoverPosts(
      minLatitude: minLatitude,
      minLongitude: minLongitude,
      maxLatitude: maxLatitude,
      maxLongitude: maxLongitude,
    );

    final postsJson = response['posts'] as List<dynamic>? ?? [];
    final parsed = <PostModel>[];
    int dropped = 0;
    for (final json in postsJson) {
      try {
        parsed.add(PostModel.fromJson(json as Map<String, dynamic>));
      } catch (e) {
        // 单条解析失败不让整批失败；统计有几条，便于定位"接口返回 N 条但前端只见 N-X 条"
        dropped++;
        debugPrint('[Repository] PostModel.fromJson DROPPED: $e — raw=$json');
      }
    }
    debugPrint(
      '[Repository] getPostsByBounds parsed=${parsed.length}'
      '${dropped > 0 ? " dropped=$dropped" : ""}',
    );
    return parsed;
  }

  @override
  Future<Map<String, dynamic>> toggleLikePost(String postId) {
    return _remoteDataSource.toggleLikePost(postId);
  }

  @override
  Future<Map<String, dynamic>> toggleFavoritePost(String postId) {
    return _remoteDataSource.toggleFavoritePost(postId);
  }

  @override
  Future<CommentModel> createComment(
    String postId, {
    required String content,
    String? parentId,
    String? replyToUserId,
  }) async {
    final response = await _remoteDataSource.createComment(
      postId,
      content: content,
      parentId: parentId,
      replyToUserId: replyToUserId,
    );

    final raw = response['comment'] ?? response['data'] ?? response;
    if (raw is Map<String, dynamic>) {
      return CommentModel.fromJson(raw);
    }
    throw Exception('Invalid comment response');
  }
}
