class JogyQrTarget {
  final String targetType;
  final String targetId;

  const JogyQrTarget({required this.targetType, required this.targetId});

  bool get isUserProfile => targetType == JogyQrCodec.userProfileType;
  bool get isPost => targetType == JogyQrCodec.postType;
}

class JogyQrCodec {
  static const userProfileType = 'user_profile';
  static const postType = 'post';

  static String userProfile(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }

    return Uri(
      scheme: 'jogy',
      host: 'user',
      pathSegments: ['profile', normalizedUserId],
    ).toString();
  }

  static JogyQrTarget? parse(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme.toLowerCase() != 'jogy') return null;

    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;

    if (host == 'user' &&
        segments.length == 2 &&
        segments[0].toLowerCase() == 'profile') {
      final userId = segments[1].trim();
      if (_isValidId(userId)) {
        return JogyQrTarget(targetType: userProfileType, targetId: userId);
      }
    }

    if (host == 'post' && segments.length == 1) {
      final postId = segments[0].trim();
      if (_isValidId(postId)) {
        return JogyQrTarget(targetType: postType, targetId: postId);
      }
    }

    return null;
  }

  static JogyQrTarget? fromResolveResponse(Map<String, dynamic> response) {
    final targetType = response['target_type'] as String?;
    final targetId = response['target_id']?.toString().trim();

    if (targetType == null || targetId == null || !_isValidId(targetId)) {
      return null;
    }

    return JogyQrTarget(targetType: targetType, targetId: targetId);
  }

  static bool _isValidId(String id) {
    return id.isNotEmpty && id.toLowerCase() != 'unknown';
  }
}
