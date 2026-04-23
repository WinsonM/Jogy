import 'package:jogy_app/core/constants/api_constants.dart';

import 'location_model.dart';
import 'user_model.dart';
import 'comment_model.dart';

class PostModel {
  final String id;
  final UserModel user;
  final LocationModel location;
  final String content;
  final List<String> imageUrls;
  final int likes;
  final bool isLiked;
  final int favorites;
  final bool isFavorited;
  final List<CommentModel> comments;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.user,
    required this.location,
    required this.content,
    required this.imageUrls,
    this.likes = 0,
    this.isLiked = false,
    this.favorites = 0,
    this.isFavorited = false,
    this.comments = const [],
    required this.createdAt,
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

    return PostModel(
      id: json['id']?.toString() ?? '',
      user: user,
      location: location,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'location': location.toJson(),
      'content': content,
      'imageUrls': imageUrls,
      'likes': likes,
      'isLiked': isLiked,
      'favorites': favorites,
      'isFavorited': isFavorited,
      'comments': comments.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PostModel copyWith({
    String? id,
    UserModel? user,
    LocationModel? location,
    String? content,
    List<String>? imageUrls,
    int? likes,
    bool? isLiked,
    int? favorites,
    bool? isFavorited,
    List<CommentModel>? comments,
    DateTime? createdAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      user: user ?? this.user,
      location: location ?? this.location,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      favorites: favorites ?? this.favorites,
      isFavorited: isFavorited ?? this.isFavorited,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
