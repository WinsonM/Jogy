import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API configuration constants for the Jogy backend
///
/// 所有敏感/个人参数从 .env 文件读取（.env 已在 .gitignore 中）
/// 提交到 GitHub 的是 .env.example（只有占位符，没有真实值）
class ApiConstants {
  /// 后端 API 地址，从 .env 读取，缺省 fallback 到 localhost
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api/v1';

  /// Server host (without /api/v1), used for resolving image/file URLs
  /// e.g. baseUrl = "https://example.com/api/v1" -> serverHost = "https://example.com"
  static String get serverHost {
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  /// WebSocket URL (wss for https, ws for http)
  static String wsUrl(String token) {
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/api/v1/ws?token=$token';
  }

  /// Resolve a relative upload path to a full URL
  /// e.g. "/uploads/images/xxx.webp" -> "https://example.com/uploads/images/xxx.webp"
  static String resolveUrl(String path) {
    if (path.startsWith('http')) return path; // already absolute
    return '$serverHost$path';
  }

  // Auth endpoints
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  static String get refreshToken => '$baseUrl/auth/refresh';
  static String get logout => '$baseUrl/auth/logout';
  static String get sendCode => '$baseUrl/auth/send-code';
  static String get verifyCode => '$baseUrl/auth/verify-code';

  // Users endpoints
  static String get userMe => '$baseUrl/users/me';
  static String get userMeQr => '$baseUrl/users/me/qr';
  static String get userMeHistory => '$baseUrl/users/me/history';
  static String userById(String userId) => '$baseUrl/users/$userId';
  static String userPosts(String userId) => '$baseUrl/users/$userId/posts';
  static String userLikedPosts(String userId) =>
      '$baseUrl/users/$userId/liked-posts';
  static String userFavoritedPosts(String userId) =>
      '$baseUrl/users/$userId/favorited-posts';
  static String followers(String userId) => '$baseUrl/users/$userId/followers';
  static String following(String userId) => '$baseUrl/users/$userId/following';
  static String follow(String userId) => '$baseUrl/users/$userId/follow';

  // Posts endpoints
  static String get posts => '$baseUrl/posts';
  static String get discover => '$baseUrl/posts/discover';
  static String get searchPosts => '$baseUrl/posts/search';
  static String postById(String id) => '$baseUrl/posts/$id';

  // Comments endpoints
  static String commentsByPost(String postId) =>
      '$baseUrl/posts/$postId/comments';
  static String commentById(String postId, String commentId) =>
      '$baseUrl/posts/$postId/comments/$commentId';

  // Likes endpoints
  static String likePost(String postId) => '$baseUrl/posts/$postId/like';
  static String likesMe(String postId) => '$baseUrl/posts/$postId/likes/me';

  // Comment likes endpoints
  static String commentLikesMe(String commentId) =>
      '$baseUrl/comments/$commentId/likes/me';

  // Favorites endpoints
  static String favoritePost(String postId) =>
      '$baseUrl/posts/$postId/favorite';
  static String favoritesMe(String postId) =>
      '$baseUrl/posts/$postId/favorites/me';

  // Conversations endpoints
  static String get conversations => '$baseUrl/conversations';
  static String get conversationsDirect => '$baseUrl/conversations/direct';
  static String conversationPin(String convId) =>
      '$baseUrl/conversations/$convId/pin';
  static String conversationById(String convId) =>
      '$baseUrl/conversations/$convId';
  static String conversationMessages(String convId) =>
      '$baseUrl/conversations/$convId/messages';
  static String conversationRead(String convId) =>
      '$baseUrl/conversations/$convId/read';

  // Activity notifications endpoints
  static String get notifications => '$baseUrl/notifications';
  static String notificationById(String id) => '$baseUrl/notifications/$id';
  static String get notificationsUnreadCount =>
      '$baseUrl/notifications/unread-count';
  static String notificationRead(String id) =>
      '$baseUrl/notifications/$id/read';
  static String get notificationsReadAll => '$baseUrl/notifications/read-all';

  // Search endpoints
  static String get searchGlobal => '$baseUrl/search/global';

  // QR endpoints
  static String get qrResolve => '$baseUrl/qr/resolve';

  // Location endpoints
  static String get locationSync => '$baseUrl/location/sync';

  // Upload endpoints
  static String get uploadImage => '$baseUrl/uploads/image';
  static String get uploadFile => '$baseUrl/uploads/file';
}
