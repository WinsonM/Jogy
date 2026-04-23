import 'package:flutter/material.dart';
import '../../../data/models/post_model.dart';
import '../../../utils/time_formatter.dart';
import 'glass_post_card.dart';

/// 帖子时间线组件
/// 按年份和月份分组显示帖子
class PostsTimeline extends StatelessWidget {
  final List<PostModel> posts;
  final Function(PostModel)? onPostTap;

  const PostsTimeline({super.key, required this.posts, this.onPostTap});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return _buildEmptyState();
    }

    // 按年份分组帖子
    final groupedByYear = _groupPostsByYear(posts);

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedByYear.length,
      itemBuilder: (context, index) {
        final year = groupedByYear.keys.elementAt(index);
        final yearPosts = groupedByYear[year]!;
        return _buildYearSection(year, yearPosts);
      },
    );
  }

  /// 构建空状态（与 PostsGridView 对齐：居中、无图标、14sp 灰色）
  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          '暂无发布',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }

  /// 按年份分组帖子
  Map<int, List<PostModel>> _groupPostsByYear(List<PostModel> posts) {
    final sorted = List<PostModel>.from(posts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final Map<int, List<PostModel>> grouped = {};
    for (final post in sorted) {
      final year = post.createdAt.year;
      grouped.putIfAbsent(year, () => []);
      grouped[year]!.add(post);
    }

    return grouped;
  }

  /// 构建年份区块
  Widget _buildYearSection(int year, List<PostModel> yearPosts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 年份标题
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            TimeFormatter.formatYearTitle(year),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        // 该年份的所有帖子
        ...yearPosts.map(
          (post) => GlassPostCard(
            post: post,
            onTap: onPostTap != null ? () => onPostTap!(post) : null,
          ),
        ),
      ],
    );
  }
}
