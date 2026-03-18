/// API configuration constants for the Jogy backend
class ApiConstants {
  // Android模拟器通常使用 10.0.2.2 访问本机 localhost
  // iOS 模拟器使用 localhost
  // 真机调试需要填写你电脑的局域网 IP
  static const String baseUrl = 'http://localhost:8000/api/v1';

  // Auth endpoints
  static const String login = '$baseUrl/login/access-token';
  static const String register = '$baseUrl/users/register';
  static const String userMe = '$baseUrl/users/me';

  // Posts endpoints
  static const String posts = '$baseUrl/posts';
  static String postById(String id) => '$baseUrl/posts/$id';
  static String postsByUser(String userId) => '$baseUrl/posts/user/$userId';

  // Discover endpoints
  static const String discover = '$baseUrl/discover';

  // Comments endpoints
  static String commentsByPost(String postId) =>
      '$baseUrl/posts/$postId/comments';

  // Likes endpoints
  static String likePost(String postId) => '$baseUrl/posts/$postId/like';
  static String unlikePost(String postId) => '$baseUrl/posts/$postId/unlike';

  // Favorites endpoints
  static String favoritePost(String postId) =>
      '$baseUrl/posts/$postId/favorite';
  static String unfavoritePost(String postId) =>
      '$baseUrl/posts/$postId/unfavorite';

  // Users endpoints
  static String userById(String userId) => '$baseUrl/users/$userId';
  static String followers(String userId) => '$baseUrl/users/$userId/followers';
  static String following(String userId) => '$baseUrl/users/$userId/following';
  static String follow(String userId) => '$baseUrl/users/$userId/follow';
  static String unfollow(String userId) => '$baseUrl/users/$userId/unfollow';
}
