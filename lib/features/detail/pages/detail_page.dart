import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../data/models/post_model.dart';
import '../../../presentation/providers/post_provider.dart';
import '../../../widgets/action_popover.dart';
import '../../profile/profile_navigation.dart';
import '../../profile/services/browsing_history_service.dart';
import 'edit_post_page.dart';
import 'image_viewer_page.dart';

class DetailPage extends StatefulWidget {
  final String? postId;

  const DetailPage({super.key, this.postId});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  PostModel? _fetchedPost;
  bool _isFetchingPost = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPostFromBackend();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshPostFromBackend() async {
    final postId = widget.postId;
    if (postId == null || !mounted) return;

    setState(() => _isFetchingPost = true);
    final fetched = await context.read<PostProvider>().getPostById(postId);
    if (!mounted) return;

    if (fetched != null) {
      context.read<PostProvider>().updatePost(fetched);
      _fetchedPost = fetched;
    }
    setState(() => _isFetchingPost = false);
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '分享',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.copy, size: 20),
                ),
                title: const Text('复制链接'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('链接已复制')));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 当前 post 是否属于本机登录用户。
  ///
  /// 用 read（非 watch）—— AuthService 在登录态变更时一般会触发整页重建，
  /// 这里再 listen 一次只是徒增开销。
  bool _isOwnPost(PostModel post) {
    final currentUserId = context.read<AuthService>().currentUserId;
    return currentUserId != null && currentUserId == post.user.id;
  }

  Future<void> _confirmDelete(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后将无法恢复，确定要删除这条内容吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await RemoteDataSource().deletePost(post.id);
      if (!mounted) return;
      context.read<PostProvider>().removePost(post.id);
      BrowsingHistoryService().removePost(post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除'), duration: Duration(seconds: 2)),
      );
      Navigator.pop(context, post.id); // 关闭详情页，并把删除结果返回给列表页
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败：${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
    }
  }

  Future<void> _openEditPage(PostModel post) async {
    final updated = await Navigator.push<PostModel>(
      context,
      MaterialPageRoute(builder: (_) => EditPostPage(post: post)),
    );
    if (updated == null || !mounted) return;
    context.read<PostProvider>().updatePost(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存'), duration: Duration(seconds: 2)),
    );
  }

  void _openImageViewer(List<String> imageUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ImageViewerPage(imageUrls: imageUrls, initialIndex: initialIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostProvider>(
      builder: (context, postProvider, child) {
        // Get the post - either by ID or use the first post as demo
        final PostModel? providerPost = widget.postId != null
            ? postProvider.posts.cast<PostModel?>().firstWhere(
                (p) => p?.id == widget.postId,
                orElse: () => null,
              )
            : (postProvider.posts.isNotEmpty ? postProvider.posts[0] : null);
        final PostModel? post = providerPost ?? _fetchedPost;

        if (post == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                '详情',
                style: TextStyle(color: Colors.black, fontSize: 18),
              ),
              centerTitle: true,
            ),
            body: Center(
              child: _isFetchingPost
                  ? const CircularProgressIndicator()
                  : const Text('Post not found'),
            ),
          );
        }

        final isOwn = _isOwnPost(post);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              '详情',
              style: TextStyle(color: Colors.black, fontSize: 18),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.black),
                onPressed: () => _showShareSheet(context),
              ),
              // 仅自己的 post 显示 "..." 菜单（编辑 / 删除）。
              // 用 [showActionPopover] 而不是 Material PopupMenuButton：
              // 原生 PopupMenu 风格生硬、白底直角，与全 app 的 glass + 圆角
              // 视觉不一致。ActionPopover 与 wheel_popover 同源审美。
              if (isOwn)
                _MoreMenuButton(
                  onEdit: () => _openEditPage(post),
                  onDelete: () => _confirmDelete(post),
                ),
            ],
          ),
          body: _buildBody(context, post, postProvider, isOwn),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    PostModel post,
    PostProvider postProvider,
    bool isOwn,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image gallery with PageView
                if (post.imageUrls.isNotEmpty)
                  Stack(
                    children: [
                      SizedBox(
                        height: 300,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: post.imageUrls.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            // 单击图片 → 全屏多图查看器（ImageViewerPage）。
                            // behavior: opaque 让 GestureDetector 即使
                            // 在 transparent 区域也吃到 tap。
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  _openImageViewer(post.imageUrls, index),
                              child: Image.network(
                                post.imageUrls[index],
                                width: double.infinity,
                                height: 300,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 300,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(Icons.error),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      // Page indicator
                      if (post.imageUrls.length > 1)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${post.imageUrls.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      // Dot indicators
                      if (post.imageUrls.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              post.imageUrls.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                // Post content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User info
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                openUserProfile(context, userId: post.user.id),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(
                                post.user.avatarUrl,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => openUserProfile(
                                context,
                                userId: post.user.id,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.user.username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    _formatTime(post.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 自己的 post 不显示"关注 / 私信" —— 没意义。
                          if (!isOwn) ...[
                            _buildFollowButton(),
                            const SizedBox(width: 8),
                            _buildMessageButton(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Post content
                      Text(
                        post.content,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                      const SizedBox(height: 16),

                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.location.placeName ??
                                '${post.location.latitude}, ${post.location.longitude}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Comments section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        '共 ${post.comments.length} 条评论',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.menu, size: 20),
                    ],
                  ),
                ),

                // Comments list
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: post.comments.length,
                  itemBuilder: (context, index) {
                    final comment = post.comments[index];
                    return _buildCommentItem(
                      context,
                      post.id,
                      comment,
                      postProvider,
                    );
                  },
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Bottom action bar
        _buildBottomBar(context, post, postProvider),
      ],
    );
  }

  Widget _buildCommentItem(
    BuildContext context,
    String postId,
    dynamic comment,
    PostProvider postProvider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(comment.avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '回复',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        postProvider.toggleCommentLike(postId, comment.id);
                      },
                      child: Row(
                        children: [
                          Icon(
                            comment.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 18,
                            color: comment.isLiked
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                          if (comment.likes > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${comment.likes}',
                              style: TextStyle(
                                color: comment.isLiked
                                    ? Colors.red
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.more_horiz, size: 20, color: Colors.grey[400]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    PostModel post,
    PostProvider postProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Input field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '说点什么...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Like button
            _buildActionButton(
              icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
              count: post.likes,
              isActive: post.isLiked,
              onTap: () => postProvider.toggleLike(post.id),
            ),
            const SizedBox(width: 16),

            // Favorite button
            _buildActionButton(
              icon: post.isFavorited ? Icons.star : Icons.star_border,
              count: post.favorites,
              isActive: post.isFavorited,
              onTap: () => postProvider.toggleFavorite(post.id),
            ),
            const SizedBox(width: 16),

            // Comment count
            _buildActionButton(
              icon: Icons.chat_bubble_outline,
              count: post.comments.length,
              isActive: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 24, color: isActive ? Colors.red : Colors.black87),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              color: isActive ? Colors.red : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    return GestureDetector(
      onTap: () {
        // TODO: Implement follow logic
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF3FAAF0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          '关注',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageButton() {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to chat page
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.mail_outline, size: 18, color: Colors.grey[700]),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }
}

/// AppBar `...` 按钮 + 弹出 [showActionPopover]（编辑 / 删除）。
///
/// 抽出来是因为 `showActionPopover` 需要一个稳定的 [GlobalKey] 锚点，
/// 而 AppBar.actions 会在 PostProvider 更新时重建，inline 写 GlobalKey
/// 会被频繁丢弃 / 新建。State 持有 key 解决这个问题。
class _MoreMenuButton extends StatefulWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MoreMenuButton({required this.onEdit, required this.onDelete});

  @override
  State<_MoreMenuButton> createState() => _MoreMenuButtonState();
}

class _MoreMenuButtonState extends State<_MoreMenuButton> {
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _anchorKey,
      icon: const Icon(Icons.more_horiz, color: Colors.black),
      tooltip: '更多',
      onPressed: () {
        showActionPopover(
          context: context,
          anchorKey: _anchorKey,
          items: [
            ActionPopoverItem(
              label: '编辑',
              icon: Icons.edit_outlined,
              onTap: widget.onEdit,
            ),
            ActionPopoverItem(
              label: '删除',
              icon: Icons.delete_outline,
              destructive: true,
              onTap: widget.onDelete,
            ),
          ],
        );
      },
    );
  }
}
