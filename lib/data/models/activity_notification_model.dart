class ActivityNotificationModel {
  final String id;
  final String type;
  final String targetType;
  final String actorName;
  final String actorAvatarUrl;
  final String targetText;
  final DateTime createdAt;
  final bool isRead;

  const ActivityNotificationModel({
    required this.id,
    required this.type,
    required this.targetType,
    required this.actorName,
    required this.actorAvatarUrl,
    required this.targetText,
    required this.createdAt,
    required this.isRead,
  });

  factory ActivityNotificationModel.fromJson(Map<String, dynamic> json) {
    final actorJson = json['actor'];
    final actor = actorJson is Map<String, dynamic> ? actorJson : null;
    final targetJson = json['target'];
    final target = targetJson is Map<String, dynamic> ? targetJson : null;
    final rawCreatedAt = json['createdAt'] ?? json['created_at'];

    return ActivityNotificationModel(
      id: json['id']?.toString() ?? '',
      type:
          json['type']?.toString() ??
          json['eventType']?.toString() ??
          json['event_type']?.toString() ??
          '',
      targetType:
          json['targetType']?.toString() ??
          json['target_type']?.toString() ??
          target?['type']?.toString() ??
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
      targetText:
          json['targetText']?.toString() ??
          json['target_text']?.toString() ??
          target?['content']?.toString() ??
          '',
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? json['is_read'] as bool? ?? false,
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
