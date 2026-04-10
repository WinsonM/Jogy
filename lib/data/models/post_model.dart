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
    return PostModel(
      id: json['id'].toString(),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      location: LocationModel.fromJson(
        json['location'] as Map<String, dynamic>,
      ),
      content: json['content'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List<dynamic>?)
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
              ?.map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'].toString()),
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
