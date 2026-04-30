import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/map/map_controller.dart';
import '../../../core/map/map_types.dart';
import '../../../data/models/post_model.dart';
import '../../../presentation/providers/post_provider.dart';
import '../clustering/close_post_grouping.dart';
import '../clustering/cluster_models.dart';
import 'map_broadcast_cloud.dart';
import 'map_bubble.dart';

/// Post / cluster 覆盖层。
///
/// 这一层只负责把当前聚合结果投影到屏幕并渲染；相机、展开、聚合面板、
/// 点赞/回复等业务状态都由 MapPage 管理。
class PostBubblesOverlay extends StatefulWidget {
  final JogyMapController controller;
  final Listenable cameraTick;
  final List<ClusterOrPoint> items;
  final List<MultiPostGroup> multiPostGroups;
  final String? expandedPostId;
  final Map<String, double> scaleFactors;
  final double mapRotation;
  final void Function(PostModel post) onPostTap;
  final void Function(PostModel post) onMultiPostTap;
  final void Function(ClusterNode cluster) onClusterTap;
  final void Function(PostModel post)? onBroadcastLike;
  final void Function(PostModel post)? onBroadcastReply;

  const PostBubblesOverlay({
    super.key,
    required this.controller,
    required this.cameraTick,
    required this.items,
    required this.multiPostGroups,
    required this.expandedPostId,
    required this.scaleFactors,
    required this.mapRotation,
    required this.onPostTap,
    required this.onMultiPostTap,
    required this.onClusterTap,
    this.onBroadcastLike,
    this.onBroadcastReply,
  });

  @override
  State<PostBubblesOverlay> createState() => _PostBubblesOverlayState();
}

class _PostBubblesOverlayState extends State<PostBubblesOverlay> {
  String? _lastDebugKey;

  @override
  void initState() {
    super.initState();
    widget.cameraTick.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant PostBubblesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraTick != widget.cameraTick) {
      oldWidget.cameraTick.removeListener(_onTick);
      widget.cameraTick.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.cameraTick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const double bubbleBoxSize = MapBubbleWidget.expandedHeight;

    final children = <Widget>[];
    Widget? expandedChild;
    var skipped = 0;
    var onscreen = 0;
    var clusters = 0;
    MapScreenPoint? firstPoint;

    for (final item in widget.items) {
      final pt = widget.controller.latLngToScreenPoint(item.center);
      if (pt == null) {
        skipped++;
        continue;
      }
      firstPoint ??= pt;
      if (_isOnscreen(pt)) onscreen++;

      if (item is ClusterNode) {
        clusters++;
        children.add(_buildClusterMarker(item, pt, bubbleBoxSize));
      } else if (item is SinglePoint) {
        final child = _buildPostMarker(item.post, pt, bubbleBoxSize);
        if (widget.expandedPostId == item.post.id && item.post.isPhotoBubble) {
          expandedChild = child;
        } else {
          children.add(child);
        }
      }
    }

    children.addAll(_buildMultiPostGroupBubbles());

    if (expandedChild != null) {
      children.add(expandedChild);
    }

    final viewport = widget.controller.cameraState.viewportSize;
    final debugKey =
        '${widget.items.length}:${children.length}:$clusters:$onscreen:'
        '$skipped:${widget.multiPostGroups.length}:'
        '${viewport.x.toStringAsFixed(0)}x${viewport.y.toStringAsFixed(0)}';
    if (_lastDebugKey != debugKey) {
      _lastDebugKey = debugKey;
      final first = firstPoint == null
          ? 'null'
          : '(${firstPoint.x.toStringAsFixed(1)},'
                '${firstPoint.y.toStringAsFixed(1)})';
      debugPrint(
        '[PostBubblesOverlay] items=${widget.items.length} '
        'children=${children.length} clusters=$clusters onscreen=$onscreen '
        'skipped=$skipped groups=${widget.multiPostGroups.length} '
        'viewport=${viewport.x.toStringAsFixed(0)}x'
        '${viewport.y.toStringAsFixed(0)} firstPt=$first',
      );
    }

    return SizedBox.expand(
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }

  bool _isOnscreen(MapScreenPoint pt) {
    final viewport = widget.controller.cameraState.viewportSize;
    return pt.x >= 0 && pt.x <= viewport.x && pt.y >= 0 && pt.y <= viewport.y;
  }

  Widget _buildClusterMarker(
    ClusterNode cluster,
    MapScreenPoint pt,
    double bubbleBoxSize,
  ) {
    return Positioned(
      key: ValueKey(cluster.id),
      left: pt.x - bubbleBoxSize / 2,
      top: pt.y - bubbleBoxSize,
      width: bubbleBoxSize,
      height: bubbleBoxSize,
      child: RepaintBoundary(
        child: MapBubbleWidget(
          isExpanded: false,
          scaleFactor: 1.0,
          cluster: cluster,
          mapRotation: widget.mapRotation,
          onTap: () => widget.onClusterTap(cluster),
        ),
      ),
    );
  }

  Widget _buildPostMarker(
    PostModel post,
    MapScreenPoint pt,
    double bubbleBoxSize,
  ) {
    if (post.isBroadcast) {
      return Positioned(
        key: ValueKey('broadcast_${post.id}'),
        left: pt.x - MapBroadcastCloudWidget.width / 2,
        top: pt.y - MapBroadcastCloudWidget.height,
        width: MapBroadcastCloudWidget.width,
        height: MapBroadcastCloudWidget.height,
        child: MapBroadcastCloudWidget(
          post: post,
          onLike: () => widget.onBroadcastLike?.call(post),
          onReply: () => widget.onBroadcastReply?.call(post),
        ),
      );
    }

    return Positioned(
      key: ValueKey('p_${post.id}'),
      left: pt.x - bubbleBoxSize / 2,
      top: pt.y - bubbleBoxSize,
      width: bubbleBoxSize,
      height: bubbleBoxSize,
      child: MapBubbleWidget(
        isExpanded: widget.expandedPostId == post.id,
        scaleFactor: widget.scaleFactors[post.id] ?? 1.0,
        post: post,
        mapRotation: widget.mapRotation,
        onTap: () => widget.onPostTap(post),
      ),
    );
  }

  List<Widget> _buildMultiPostGroupBubbles() {
    const width = _MapMultiPostBubbleWidget.width;
    const height = _MapMultiPostBubbleWidget.height;
    final out = <Widget>[];
    for (final group in widget.multiPostGroups) {
      final center = widget.controller.latLngToScreenPoint(group.center);
      if (center == null) continue;
      out.add(
        Positioned(
          key: ValueKey(group.id),
          left: center.x - width / 2,
          top: center.y - height,
          width: width,
          height: height,
          child: _MapMultiPostBubbleWidget(
            posts: group.posts,
            totalCount: group.totalCount,
            onPostTap: widget.onMultiPostTap,
            onBroadcastLike: widget.onBroadcastLike,
            onBroadcastReply: widget.onBroadcastReply,
          ),
        ),
      );
    }
    return out;
  }
}

class _MapMultiPostBubbleWidget extends StatefulWidget {
  static const double width = 288.0;
  static const double height = 348.0;

  final List<PostModel> posts;
  final int totalCount;
  final void Function(PostModel post) onPostTap;
  final void Function(PostModel post)? onBroadcastLike;
  final void Function(PostModel post)? onBroadcastReply;

  const _MapMultiPostBubbleWidget({
    required this.posts,
    required this.totalCount,
    required this.onPostTap,
    this.onBroadcastLike,
    this.onBroadcastReply,
  });

  @override
  State<_MapMultiPostBubbleWidget> createState() =>
      _MapMultiPostBubbleWidgetState();
}

class _MapMultiPostBubbleWidgetState extends State<_MapMultiPostBubbleWidget> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _MapMultiPostBubbleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.posts.length) {
      _page = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extraCount = widget.totalCount - widget.posts.length;
    final counter = extraCount > 0
        ? '${_page + 1}/${widget.posts.length} · 共 ${widget.totalCount}'
        : '${_page + 1}/${widget.posts.length}';

    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: const Size(
              _MapMultiPostBubbleWidget.width,
              _MapMultiPostBubbleWidget.height,
            ),
            painter: BubblePainter(
              color: const Color(0xF2FFFFFF),
              isExpanded: true,
            ),
          ),
          ClipPath(
            clipper: BubbleClipper(isExpanded: true),
            child: SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 17,
                          color: Color(0xFF3FAAF0),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            '此处多条内容',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF27313A),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          counter,
                          style: const TextStyle(
                            color: Color(0xFF52616D),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: widget.posts.length,
                        onPageChanged: (value) => setState(() => _page = value),
                        itemBuilder: (context, index) {
                          final post = widget.posts[index];
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: post.isBroadcast
                                ? _MultiBroadcastPage(
                                    key: ValueKey('broadcast_${post.id}'),
                                    post: post,
                                    onTap: () => widget.onPostTap(post),
                                    onLike: () =>
                                        widget.onBroadcastLike?.call(post),
                                    onReply: () =>
                                        widget.onBroadcastReply?.call(post),
                                  )
                                : _MultiBubblePage(
                                    key: ValueKey('bubble_${post.id}'),
                                    post: post,
                                    onTap: () => widget.onPostTap(post),
                                  ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PageDots(count: widget.posts.length, current: _page),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiBubblePage extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;

  const _MultiBubblePage({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl == null
                  ? Container(
                      color: const Color(0xFFE9EEF2),
                      child: const Center(
                        child: Icon(Icons.image, color: Colors.grey),
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE9EEF2),
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundImage: NetworkImage(post.user.avatarUrl),
                onBackgroundImageError: (_, __) {},
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  post.user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF27313A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Consumer<PostProvider>(
                builder: (context, postProvider, child) {
                  final currentPost = postProvider.posts.firstWhere(
                    (candidate) => candidate.id == post.id,
                    orElse: () => post,
                  );
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => postProvider.toggleLike(currentPost.id),
                        child: SizedBox(
                          height: 30,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                currentPost.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 19,
                                color: currentPost.isLiked
                                    ? const Color(0xFFE84D4D)
                                    : Colors.black45,
                              ),
                              if (currentPost.likes > 0) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '${currentPost.likes}',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            postProvider.toggleFavorite(currentPost.id),
                        child: SizedBox(
                          height: 30,
                          child: Icon(
                            currentPost.isFavorited
                                ? Icons.star
                                : Icons.star_border,
                            size: 21,
                            color: currentPost.isFavorited
                                ? Colors.amber
                                : Colors.black45,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              post.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF27313A),
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MultiBroadcastPage extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _MultiBroadcastPage({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFD),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x14000000)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_outlined,
                        size: 18,
                        color: Color(0xFF3FAAF0),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.user.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF27313A),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: Text(
                        post.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF27313A),
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MultiActionButton(
              icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
              label: post.likes > 0 ? '${post.likes}' : '',
              color: post.isLiked
                  ? const Color(0xFFE84D4D)
                  : const Color(0xFF52616D),
              onTap: onLike,
            ),
            _MultiActionButton(
              icon: Icons.mode_comment_outlined,
              label: '',
              color: const Color(0xFF52616D),
              onTap: onReply,
            ),
          ],
        ),
      ],
    );
  }
}

class _MultiActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MultiActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 30,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;

  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final visibleCount = count < 8 ? count : 8;
    final activeDot = count <= visibleCount
        ? current
        : ((current / (count - 1)) * (visibleCount - 1)).round();
    return SizedBox(
      height: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < visibleCount; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: i == activeDot ? 12 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: i == activeDot
                    ? const Color(0xFF3FAAF0)
                    : const Color(0x333FAAF0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
