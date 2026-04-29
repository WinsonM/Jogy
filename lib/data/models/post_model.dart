import 'package:jogy_app/core/constants/api_constants.dart';

import 'location_model.dart';
import 'user_model.dart';
import 'comment_model.dart';

class PostModel {
  final String id;
  final UserModel user;
  final LocationModel location;

  /// 可选标题（短文案，max 100 字）。后端 `Post.title: Optional[str]`。
  final String? title;

  final String content;
  final List<String> imageUrls;
  final int likes;
  final bool isLiked;
  final int favorites;
  final bool isFavorited;
  final List<CommentModel> comments;
  final DateTime createdAt;

  /// 过期时间（UTC ISO8601）。null = 永久。
  ///
  /// 用于 profile UI 区分"活跃 / 已过期"——后端 `/users/{id}/posts` 不 filter，
  /// 但 `/posts/discover` 会 `expire_at IS NULL OR expire_at > now()` 卡掉过期，
  /// 导致 profile 看得到、map 看不到。前端用 [expireAt] 显式标记。
  final DateTime? expireAt;

  bool get isExpired => expireAt != null && expireAt!.isBefore(DateTime.now());

  /// 广播：无照片的地图短讯息。显示为云朵，不进入收藏/喜欢列表。
  bool get isBroadcast => imageUrls.isEmpty;

  /// 气泡：包含照片的长期讯息。沿用照片气泡视觉与收藏能力。
  bool get isPhotoBubble => imageUrls.isNotEmpty;

  bool get canFavorite => isPhotoBubble;

  const PostModel({
    required this.id,
    required this.user,
    required this.location,
    this.title,
    required this.content,
    required this.imageUrls,
    this.likes = 0,
    this.isLiked = false,
    this.favorites = 0,
    this.isFavorited = false,
    this.comments = const [],
    required this.createdAt,
    this.expireAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Safe user parse — 缺失/null 不再崩溃
    final userJson = json['user'];
    final user = (userJson is Map<String, dynamic>)
        ? UserModel.fromJson(userJson)
        : const UserModel(id: '', username: '未知', avatarUrl: '', bio: '');

    // Safe location parse
    final locJson = json['location'];
    final location = (locJson is Map<String, dynamic>)
        ? LocationModel.fromJson(locJson)
        : const LocationModel(latitude: 0, longitude: 0);

    // Safe createdAt parse
    DateTime createdAt;
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    // Safe expireAt parse — null 表示永久
    DateTime? expireAt;
    final rawExpireAt = json['expireAt'];
    if (rawExpireAt is String) {
      expireAt = DateTime.tryParse(rawExpireAt);
    }

    return PostModel(
      id: json['id']?.toString() ?? '',
      user: user,
      location: location,
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      imageUrls:
          (json['imageUrls'] as List<dynamic>?)
              ?.cast<String>()
              .map((url) => ApiConstants.resolveUrl(url))
              .toList() ??
          [],
      likes: json['likes'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      favorites: json['favorites'] as int? ?? 0,
      isFavorited: json['isFavorited'] as bool? ?? false,
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((e) {
                try {
                  return CommentModel.fromJson(e as Map<String, dynamic>);
                } catch (_) {
                  return null;
                }
              })
              .whereType<CommentModel>()
              .toList() ??
          [],
      createdAt: createdAt,
      expireAt: expireAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'location': location.toJson(),
      'title': title,
      'content': content,
      'imageUrls': imageUrls,
      'likes': likes,
      'isLiked': isLiked,
      'favorites': favorites,
      'isFavorited': isFavorited,
      'comments': comments.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'expireAt': expireAt?.toIso8601String(),
    };
  }

  PostModel copyWith({
    String? id,
    UserModel? user,
    LocationModel? location,
    String? title,
    String? content,
    List<String>? imageUrls,
    int? likes,
    bool? isLiked,
    int? favorites,
    bool? isFavorited,
    List<CommentModel>? comments,
    DateTime? createdAt,
    DateTime? expireAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      user: user ?? this.user,
      location: location ?? this.location,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      favorites: favorites ?? this.favorites,
      isFavorited: isFavorited ?? this.isFavorited,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      expireAt: expireAt ?? this.expireAt,
    );
  }
}
