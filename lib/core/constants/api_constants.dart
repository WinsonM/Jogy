/// API configuration constants for the Jogy backend
class ApiConstants {
  // 通过编译时参数切换环境，无需改代码：
  //
  // 本地开发（默认）:
  //   flutter run
  //
  // Android 模拟器:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  //
  // 真机调试（替换为电脑局域网 IP）:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api/v1
  //
  // 生产环境打包:
  //   flutter build apk --dart-define=API_BASE_URL=https://your-domain.com/api/v1
  //   flutter build ios --dart-define=API_BASE_URL=https://your-domain.com/api/v1
  //
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

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
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String refreshToken = '$baseUrl/auth/refresh';
  static const String logout = '$baseUrl/auth/logout';
  static const String sendCode = '$baseUrl/auth/send-code';
  static const String verifyCode = '$baseUrl/auth/verify-code';

  // Users endpoints
  static const String userMe = '$baseUrl/users/me';
  static const String userMeQr = '$baseUrl/users/me/qr';
  static const String userMeHistory = '$baseUrl/users/me/history';
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
  static const String posts = '$baseUrl/posts';
  static const String discover = '$baseUrl/posts/discover';
  static const String searchPosts = '$baseUrl/posts/search';
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
  static const String conversations = '$baseUrl/conversations';
  static const String conversationsDirect = '$baseUrl/conversations/direct';
  static String conversationPin(String convId) =>
      '$baseUrl/conversations/$convId/pin';
  static String conversationById(String convId) =>
      '$baseUrl/conversations/$convId';
  static String conversationMessages(String convId) =>
      '$baseUrl/conversations/$convId/messages';
  static String conversationRead(String convId) =>
      '$baseUrl/conversations/$convId/read';

  // Search endpoints
  static const String searchGlobal = '$baseUrl/search/global';

  // QR endpoints
  static const String qrResolve = '$baseUrl/qr/resolve';

  // Location endpoints
  static const String locationSync = '$baseUrl/location/sync';

  // Upload endpoints
  static const String uploadImage = '$baseUrl/uploads/image';
  static const String uploadFile = '$baseUrl/uploads/file';
}
