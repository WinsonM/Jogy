import 'package:flutter/material.dart';

import '../../../data/datasources/remote_data_source.dart';
import '../../../data/models/activity_notification_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<ActivityNotificationModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = RemoteDataSource().fetchActivityNotifications();
  }

  void _reload() {
    setState(() {
      _future = RemoteDataSource().fetchActivityNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        title: const Text(
          '通知',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<ActivityNotificationModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 60,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    snapshot.hasError ? '通知暂不可用' : '暂无通知',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _NotificationTile(item: items[index]);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final ActivityNotificationModel item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final icon = item.isReply
        ? Icons.mode_comment_outlined
        : item.isLike
        ? Icons.favorite_border
        : Icons.notifications_none;
    final iconColor = item.isReply
        ? const Color(0xFF3FAAF0)
        : item.isLike
        ? const Color(0xFFE84D4D)
        : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x12000000)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE9EEF2),
            backgroundImage: item.actorAvatarUrl.isNotEmpty
                ? NetworkImage(item.actorAvatarUrl)
                : null,
            child: item.actorAvatarUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.targetText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.targetText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatTime(item.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          if (!item.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, left: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFE84D4D),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}
