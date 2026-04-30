import 'package:flutter_test/flutter_test.dart';
import 'package:jogy_app/data/models/activity_notification_model.dart';

void main() {
  group('ActivityNotificationModel', () {
    test('parses official notification payload', () {
      final notification = ActivityNotificationModel.fromJson({
        'id': 'n-1',
        'type': 'post_reply',
        'target_type': 'broadcast',
        'post_id': 'post-1',
        'comment_id': 'comment-1',
        'target_preview': '广播内容',
        'created_at': '2026-04-29T10:00:00Z',
        'read_at': null,
        'actor': {
          'id': 'user-2',
          'username': 'Alice',
          'avatar_url': 'https://example.com/a.png',
        },
      });

      expect(notification.id, 'n-1');
      expect(notification.postId, 'post-1');
      expect(notification.commentId, 'comment-1');
      expect(notification.actorUserId, 'user-2');
      expect(notification.targetPreview, '广播内容');
      expect(notification.isBroadcast, isTrue);
      expect(notification.isReply, isTrue);
      expect(notification.isRead, isFalse);
      expect(notification.title, 'Alice 回复了你的广播');
    });

    test('parses notification page payload', () {
      final page = ActivityNotificationPage.fromJson({
        'unread_count': 2,
        'notifications': [
          {
            'id': 'n-1',
            'type': 'post_like',
            'target_type': 'bubble',
            'post_id': 'post-1',
            'target_preview': '气泡内容',
            'created_at': '2026-04-29T10:00:00Z',
            'read_at': '2026-04-29T10:01:00Z',
            'actor': {'id': 'user-2', 'username': 'Bob'},
          },
        ],
      });

      expect(page.unreadCount, 2);
      expect(page.notifications, hasLength(1));
      expect(page.notifications.first.isLike, isTrue);
      expect(page.notifications.first.isRead, isTrue);
    });
  });
}
