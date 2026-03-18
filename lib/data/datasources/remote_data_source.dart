import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';

/// Remote data source for API calls to the Jogy backend
class RemoteDataSource {
  final Dio _dio;

  RemoteDataSource({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// Set the authorization token for authenticated requests
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear the authorization token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  // ==================== Auth ====================

  /// Login with username and password
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'Login failed');
    }
  }

  /// Get current user info
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiConstants.userMe);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to get user info');
    }
  }

  // ==================== Posts ====================

  /// Fetch all posts
  Future<List<PostModel>> fetchPosts({int skip = 0, int limit = 20}) async {
    try {
      final response = await _dio.get(
        ApiConstants.posts,
        queryParameters: {'skip': skip, 'limit': limit},
      );
      return (response.data as List)
          .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to load posts');
    }
  }

  /// Fetch a single post by ID
  Future<PostModel> fetchPostById(String postId) async {
    try {
      final response = await _dio.get(ApiConstants.postById(postId));
      return PostModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to load post');
    }
  }

  /// Fetch posts by user ID
  Future<List<PostModel>> fetchPostsByUser(String userId) async {
    try {
      final response = await _dio.get(ApiConstants.postsByUser(userId));
      return (response.data as List)
          .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to load user posts');
    }
  }

  /// Create a new post
  Future<PostModel> createPost({
    required String content,
    required double latitude,
    required double longitude,
    List<String>? imageUrls,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.posts,
        data: {
          'content': content,
          'latitude': latitude,
          'longitude': longitude,
          'image_urls': imageUrls ?? [],
        },
      );
      return PostModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to create post');
    }
  }

  // ==================== Discover ====================

  /// Fetch posts for discover (location-based)
  Future<List<PostModel>> fetchDiscoverPosts({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.discover,
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'radius_km': radiusKm,
          'limit': limit,
        },
      );
      return (response.data as List)
          .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to load discover posts');
    }
  }

  // ==================== Likes & Favorites ====================

  /// Like a post
  Future<void> likePost(String postId) async {
    try {
      await _dio.post(ApiConstants.likePost(postId));
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to like post');
    }
  }

  /// Unlike a post
  Future<void> unlikePost(String postId) async {
    try {
      await _dio.delete(ApiConstants.unlikePost(postId));
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to unlike post');
    }
  }

  /// Favorite a post
  Future<void> favoritePost(String postId) async {
    try {
      await _dio.post(ApiConstants.favoritePost(postId));
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to favorite post');
    }
  }

  /// Unfavorite a post
  Future<void> unfavoritePost(String postId) async {
    try {
      await _dio.delete(ApiConstants.unfavoritePost(postId));
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to unfavorite post');
    }
  }

  // ==================== Users ====================

  /// Get user by ID
  Future<UserModel> fetchUserById(String userId) async {
    try {
      final response = await _dio.get(ApiConstants.userById(userId));
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to load user');
    }
  }

  /// Follow a user
  Future<void> followUser(String userId) async {
    try {
      await _dio.post(ApiConstants.follow(userId));
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to follow user');
    }
  }

  /// Unfollow a user
  Future<void> unfollowUser(String userId) async {
    try {
      await _dio.delete(ApiConstants.unfollow(userId));
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to unfollow user');
    }
  }

  // ==================== Error Handling ====================

  Exception _handleDioError(DioException e, String defaultMessage) {
    if (e.response != null) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      String errorMessage = defaultMessage;
      if (data is Map<String, dynamic> && data.containsKey('detail')) {
        errorMessage = data['detail'].toString();
      }

      switch (statusCode) {
        case 401:
          return Exception('Unauthorized: $errorMessage');
        case 403:
          return Exception('Forbidden: $errorMessage');
        case 404:
          return Exception('Not found: $errorMessage');
        case 422:
          return Exception('Validation error: $errorMessage');
        default:
          return Exception('$defaultMessage: $errorMessage');
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('Connection timeout. Please check your network.');
    } else if (e.type == DioExceptionType.connectionError) {
      return Exception('Connection error. Is the server running?');
    }
    return Exception('$defaultMessage: ${e.message}');
  }
}
