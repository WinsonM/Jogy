import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../data/models/post_model.dart';
import '../../../utils/time_formatter.dart';

/// 玻璃态帖子卡片组件
/// 显示日期、9宫格图片缩略图和单行文字内容
class GlassPostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const GlassPostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(120),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧日期显示
                  _buildDateColumn(),
                  const SizedBox(width: 12),
                  // 中间9宫格图片
                  if (post.imageUrls.isNotEmpty) ...[
                    _buildImageGrid(),
                    const SizedBox(width: 12),
                  ],
                  // 右侧文字内容
                  Expanded(child: _buildContentText()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建左侧日期列
  Widget _buildDateColumn() {
    return SizedBox(
      width: 48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期数字
          Text(
            post.createdAt.day.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          // 月份
          Text(
            '${post.createdAt.month}月',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 构建9宫格图片
  Widget _buildImageGrid() {
    // 最多显示9张图片
    final displayImages = post.imageUrls.take(9).toList();
    final imageCount = displayImages.length;

    // 根据图片数量决定列数
    int crossAxisCount;
    if (imageCount == 1) {
      crossAxisCount = 1;
    } else if (imageCount <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    // 计算每个图片的大小
    const double gridSize = 80;
    final double itemSize =
        (gridSize - (crossAxisCount - 1) * 2) / crossAxisCount;

    return SizedBox(
      width: gridSize,
      height: gridSize,
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: displayImages.map((url) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              url,
              width: itemSize,
              height: itemSize,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: itemSize,
                  height: itemSize,
                  color: Colors.grey[300],
                  child: Icon(
                    Icons.image_not_supported,
                    size: itemSize * 0.5,
                    color: Colors.grey[500],
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 构建文字内容
  Widget _buildContentText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 内容文字（单行截断）
        Text(
          post.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        // 发布时间
        Text(
          TimeFormatter.formatRelative(post.createdAt),
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
