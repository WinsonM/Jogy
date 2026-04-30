class ActivityNotificationModel {
  final String id;
  final String type;
  final String targetType;
  final String postId;
  final String? commentId;
  final String actorUserId;
  final String actorName;
  final String actorAvatarUrl;
  final String targetPreview;
  final DateTime createdAt;
  final DateTime? readAt;

  const ActivityNotificationModel({
    required this.id,
    required this.type,
    required this.targetType,
    required this.postId,
    this.commentId,
    required this.actorUserId,
    required this.actorName,
    required this.actorAvatarUrl,
    required this.targetPreview,
    required this.createdAt,
    this.readAt,
  });

  factory ActivityNotificationModel.fromJson(Map<String, dynamic> json) {
    final actorJson = json['actor'];
    final actor = actorJson is Map<String, dynamic> ? actorJson : null;
    final targetJson = json['target'];
    final target = targetJson is Map<String, dynamic> ? targetJson : null;
    final rawCreatedAt = json['createdAt'] ?? json['created_at'];
    final rawReadAt = json['readAt'] ?? json['read_at'];
    final targetType =
        json['targetType']?.toString() ??
        json['target_type']?.toString() ??
        target?['type']?.toString() ??
        '';

    return ActivityNotificationModel(
      id: json['id']?.toString() ?? '',
      type:
          json['type']?.toString() ??
          json['eventType']?.toString() ??
          json['event_type']?.toString() ??
          '',
      targetType: targetType,
      postId:
          json['postId']?.toString() ??
          json['post_id']?.toString() ??
          target?['postId']?.toString() ??
          target?['post_id']?.toString() ??
          target?['id']?.toString() ??
          '',
      commentId:
          json['commentId']?.toString() ??
          json['comment_id']?.toString() ??
          target?['commentId']?.toString() ??
          target?['comment_id']?.toString(),
      actorUserId:
          json['actorUserId']?.toString() ??
          json['actor_user_id']?.toString() ??
          actor?['id']?.toString() ??
          '',
      actorName:
          json['actorName']?.toString() ??
          json['actor_name']?.toString() ??
          actor?['username']?.toString() ??
          '有人',
      actorAvatarUrl:
          json['actorAvatarUrl']?.toString() ??
          json['actor_avatar_url']?.toString() ??
          actor?['avatarUrl']?.toString() ??
          actor?['avatar_url']?.toString() ??
          '',
      targetPreview:
          json['targetPreview']?.toString() ??
          json['target_preview']?.toString() ??
          json['targetText']?.toString() ??
          json['target_text']?.toString() ??
          target?['content']?.toString() ??
          target?['preview']?.toString() ??
          '',
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
          : DateTime.now(),
      readAt: rawReadAt is String ? DateTime.tryParse(rawReadAt) : null,
    );
  }

  bool get isRead => readAt != null;
  String get targetText => targetPreview;

  ActivityNotificationModel copyWith({DateTime? readAt}) {
    return ActivityNotificationModel(
      id: id,
      type: type,
      targetType: targetType,
      postId: postId,
      commentId: commentId,
      actorUserId: actorUserId,
      actorName: actorName,
      actorAvatarUrl: actorAvatarUrl,
      targetPreview: targetPreview,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  bool get isLike => type.toLowerCase().contains('like');
  bool get isReply {
    final value = type.toLowerCase();
    return value.contains('reply') || value.contains('comment');
  }

  bool get isBroadcast =>
      targetType == 'broadcast' || targetType == 'post_broadcast';

  String get title {
    final targetLabel = isBroadcast ? '广播' : '气泡';
    if (isReply) return '$actorName 回复了你的$targetLabel';
    if (isLike) return '$actorName 点赞了你的$targetLabel';
    return '$actorName 有新的互动';
  }
}

class ActivityNotificationPage {
  final List<ActivityNotificationModel> notifications;
  final int unreadCount;

  const ActivityNotificationPage({
    required this.notifications,
    required this.unreadCount,
  });

  factory ActivityNotificationPage.fromJson(Map<String, dynamic> json) {
    final rawList = json['notifications'];
    final list = rawList is List
        ? rawList
              .whereType<Map<String, dynamic>>()
              .map(ActivityNotificationModel.fromJson)
              .toList()
        : <ActivityNotificationModel>[];

    return ActivityNotificationPage(
      notifications: list,
      unreadCount:
          json['unread_count'] as int? ?? json['unreadCount'] as int? ?? 0,
    );
  }
}
