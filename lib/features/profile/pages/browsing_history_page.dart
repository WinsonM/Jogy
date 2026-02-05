import 'package:flutter/material.dart';
import '../services/browsing_history_service.dart';
import '../widgets/posts_timeline.dart';

class BrowsingHistoryPage extends StatelessWidget {
  const BrowsingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final history = BrowsingHistoryService().getHistory();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 主要内容
          history.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: topPadding + 60),
                      PostsTimeline(
                        posts: history,
                        onPostTap: (post) {
                          // TODO: Navigate to post detail
                        },
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
          // 顶部导航栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.only(top: topPadding),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '浏览历史',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // 清空按钮
                  if (history.isNotEmpty)
                    TextButton(
                      onPressed: () => _showClearConfirmation(context),
                      child: const Text(
                        '清空',
                        style: TextStyle(fontSize: 14, color: Colors.red),
                      ),
                    )
                  else
                    const SizedBox(width: 48), // Placeholder for alignment
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('暂无浏览记录', style: TextStyle(fontSize: 16, color: Colors.grey)),
          SizedBox(height: 8),
          Text(
            '浏览过的帖子会显示在这里',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空浏览历史'),
        content: const Text('确定要清空所有浏览记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              BrowsingHistoryService().clearHistory();
              Navigator.pop(ctx);
              // Rebuild the page
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const BrowsingHistoryPage()),
              );
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
