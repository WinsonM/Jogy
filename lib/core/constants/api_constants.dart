/// API configuration constants for the Jogy backend
class ApiConstants {
  // Android模拟器通常使用 10.0.2.2 访问本机 localhost
  // iOS 模拟器使用 localhost
  // 真机调试需要填写你电脑的局域网 IP
  static const String baseUrl = 'http://localhost:8000/api/v1';

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
