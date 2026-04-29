class CommentModel {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final String content;
  final DateTime createdAt;
  final int likes;
  final bool isLiked;
  final String? replyToUserId;
  final bool isPrivate;

  const CommentModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.content,
    required this.createdAt,
    this.likes = 0,
    this.isLiked = false,
    this.replyToUserId,
    this.isPrivate = false,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final user = userJson is Map<String, dynamic> ? userJson : null;
    final rawCreatedAt = json['createdAt'] ?? json['created_at'];
    final createdAt = rawCreatedAt is String
        ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
        : DateTime.now();

    return CommentModel(
      id: json['id']?.toString() ?? '',
      userId:
          json['userId']?.toString() ??
          json['user_id']?.toString() ??
          user?['id']?.toString() ??
          '',
      username:
          json['username']?.toString() ??
          user?['username']?.toString() ??
          '未知用户',
      avatarUrl:
          json['avatarUrl']?.toString() ??
          json['avatar_url']?.toString() ??
          user?['avatarUrl']?.toString() ??
          user?['avatar_url']?.toString() ??
          '',
      content: json['content']?.toString() ?? '',
      createdAt: createdAt,
      likes: json['likes'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      replyToUserId:
          json['replyToUserId']?.toString() ??
          json['reply_to_user_id']?.toString(),
      isPrivate:
          json['isPrivate'] as bool? ?? json['is_private'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      'isLiked': isLiked,
      'replyToUserId': replyToUserId,
      'isPrivate': isPrivate,
    };
  }

  CommentModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? avatarUrl,
    String? content,
    DateTime? createdAt,
    int? likes,
    bool? isLiked,
    String? replyToUserId,
    bool? isPrivate,
  }) {
    return CommentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      replyToUserId: replyToUserId ?? this.replyToUserId,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}
