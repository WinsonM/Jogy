import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../data/models/post_model.dart';

/// A grid view that displays posts as cards in a 2-column staggered layout
/// Similar to Xiaohongshu/Pinterest style
class PostsGridView extends StatelessWidget {
  final List<PostModel> posts;
  final void Function(PostModel post)? onPostTap;

  const PostsGridView({super.key, required this.posts, this.onPostTap});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '暂无内容',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _PostCard(post: post, onTap: () => onPostTap?.call(post));
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const _PostCard({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: AspectRatio(
                aspectRatio: _getRandomAspectRatio(),
                child: Image.network(
                  post.imageUrls.isNotEmpty
                      ? post.imageUrls.first
                      : 'https://picsum.photos/200/300?random=${post.id.hashCode}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title/content text
                  Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // User info and likes
                  Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: NetworkImage(post.user.avatarUrl),
                      ),
                      const SizedBox(width: 4),
                      // Username
                      Expanded(
                        child: Text(
                          post.user.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      // Like count
                      Icon(Icons.favorite, size: 12, color: Colors.red[300]),
                      const SizedBox(width: 2),
                      Text(
                        _formatLikeCount(post.likes),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate varied aspect ratios for visual interest
  double _getRandomAspectRatio() {
    final ratios = [0.75, 0.8, 1.0, 1.2];
    return ratios[post.id.hashCode.abs() % ratios.length];
  }

  String _formatLikeCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
