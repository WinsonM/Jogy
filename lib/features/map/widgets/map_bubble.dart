import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/post_model.dart';
import '../../../presentation/providers/post_provider.dart';
import '../clustering/cluster_models.dart';

// 核心组件：动态气泡
//
// 两种模式：
// - 单点模式：传入 [post]，显示头像（展开后显示完整卡片）
// - 聚合模式：传入 [cluster]，显示气泡内数量；不支持展开
//
// [post] 与 [cluster] **互斥**：必须且仅有一个非空。
class MapBubbleWidget extends StatelessWidget {
  static const double collapsedSize = 60.0;
  static const double expandedSize = 280.0;
  static const double expandedHeightFactor = 1.2;
  static const double expandedHeight = expandedSize * expandedHeightFactor;
  static const double arrowHeight = 15.0;

  final bool isExpanded;
  final VoidCallback onTap;
  final double scaleFactor;

  /// 单点模式：post 不为 null
  final PostModel? post;

  /// 聚合模式：cluster 不为 null
  final ClusterNode? cluster;

  final double mapRotation; // 地图旋转角度（弧度）

  const MapBubbleWidget({
    super.key,
    required this.isExpanded,
    required this.onTap,
    this.scaleFactor = 1.0,
    this.post,
    this.cluster,
    this.mapRotation = 0.0,
  }) : assert(
          (post != null) ^ (cluster != null),
          'MapBubbleWidget 必须且仅能提供 post 或 cluster 之一',
        );

  bool get _isCluster => cluster != null;

  @override
  Widget build(BuildContext context) {
    // Cluster 不支持展开态，强制使用 collapsed 尺寸
    final effectiveExpanded = isExpanded && !_isCluster;
    final double baseSize = effectiveExpanded ? expandedSize : collapsedSize;
    final double bubbleHeight =
        effectiveExpanded ? expandedHeight : collapsedSize;

    return GestureDetector(
      onTap: onTap,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Transform.rotate(
          angle: -mapRotation, // 反向旋转以保持气泡垂直
          alignment: Alignment.bottomCenter, // 以底部尖端为中心旋转
          child: Transform.scale(
            scale: scaleFactor,
            alignment: Alignment.bottomCenter, // Scale from bottom tip
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              width: baseSize,
              height: bubbleHeight,
              child: Stack(
                alignment: Alignment.bottomCenter, // Align content from bottom
                clipBehavior: Clip.none,
                children: [
                  // 玻璃模糊效果层 —— 只在「展开的单点」上渲染
                  // cluster / 未展开单点 都跳过 BackdropFilter 以节省 GPU 开销
                  if (effectiveExpanded)
                    ClipPath(
                      clipper: BubbleClipper(isExpanded: true),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: baseSize,
                          height: bubbleHeight,
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  // 气泡颜色层
                  CustomPaint(
                    size: Size(baseSize, bubbleHeight),
                    painter: BubblePainter(
                      color: _bubbleColor(),
                      isExpanded: effectiveExpanded,
                    ),
                  ),
                  if (scaleFactor >= 0.5)
                    ClipPath(
                      clipper: BubbleClipper(isExpanded: effectiveExpanded),
                      child: SizedBox.expand(
                        child: effectiveExpanded
                            ? _buildExpandedContent(context)
                            : _buildCollapsedContent(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 气泡主色：cluster 按数量分级，单点沿用原本的蓝色
  Color _bubbleColor() {
    if (_isCluster) {
      final n = cluster!.count;
      if (n < 10) return const Color(0xCC3FAAF0); // 蓝（同单点，稍高不透明度）
      if (n < 50) return const Color(0xCCFF9500); // 橙
      return const Color(0xCCFF3B30); // 红
    }
    return const Color(0x993FAAF0); // 0x99 = 60% 不透明度
  }

  Widget _buildCollapsedContent() {
    if (_isCluster) {
      return _buildClusterContent();
    }
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 5), // Center inside the circle
        child: CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(post!.user.avatarUrl),
          onBackgroundImageError: (_, __) {},
        ),
      ),
    );
  }

  /// 聚合数量显示：99+ / 999+ 截断
  Widget _buildClusterContent() {
    final n = cluster!.count;
    final label = n > 999
        ? '999+'
        : n > 99
            ? '99+'
            : '$n';
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2.0,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    // 仅在 !_isCluster 分支才会进入（见 build()），post 非空可断言
    final p = post!;
    final imageUrl = p.imageUrls.isNotEmpty ? p.imageUrls[0] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 22), // 底部减少以平衡上下空间
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, color: Colors.grey),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(height: 6), // 减少间距
          // 底部：左边用户头像，右边 like 和 star 按钮
          Consumer<PostProvider>(
            builder: (context, postProvider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 左边：用户头像
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(p.user.avatarUrl),
                      onBackgroundImageError: (_, __) {},
                    ),
                    // 右边：like 和 star 按钮横向排列
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Like 按钮
                        GestureDetector(
                          onTap: () {
                            postProvider.toggleLike(p.id);
                          },
                          child: Icon(
                            p.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 22,
                            color: p.isLiked ? Colors.red : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Star 按钮
                        GestureDetector(
                          onTap: () {
                            postProvider.toggleFavorite(p.id);
                          },
                          child: Icon(
                            p.isFavorited ? Icons.star : Icons.star_border,
                            size: 22,
                            color: p.isFavorited
                                ? Colors.amber
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// 自定义画笔
class BubblePainter extends CustomPainter {
  final Color color;
  final bool isExpanded;

  BubblePainter({required this.color, required this.isExpanded});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = _buildBubblePath(size, isExpanded);
    canvas.drawShadow(path, Colors.black.withOpacity(0.15), 10.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BubbleClipper extends CustomClipper<Path> {
  final bool isExpanded;

  BubbleClipper({required this.isExpanded});

  @override
  Path getClip(Size size) => _buildBubblePath(size, isExpanded);

  @override
  bool shouldReclip(covariant BubbleClipper oldClipper) {
    return oldClipper.isExpanded != isExpanded;
  }
}

Path _buildBubblePath(Size size, bool isExpanded) {
  final path = Path();
  final w = size.width;
  final h = size.height;
  final r = isExpanded ? 24.0 : w / 2;

  if (!isExpanded) {
    final circlePath = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w / 2, h / 2 - 5), radius: w / 2 - 5),
      );
    final arrow = Path()
      ..moveTo(w / 2 - 8, h - MapBubbleWidget.arrowHeight)
      ..lineTo(w / 2, h)
      ..lineTo(w / 2 + 8, h - MapBubbleWidget.arrowHeight)
      ..close();
    return Path.combine(PathOperation.union, circlePath, arrow);
  }

  path.moveTo(r, 0);
  path.lineTo(w - r, 0);
  path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
  path.lineTo(w, h - MapBubbleWidget.arrowHeight - r);
  path.arcToPoint(
    Offset(w - r, h - MapBubbleWidget.arrowHeight),
    radius: Radius.circular(r),
  );

  // Curved Tail Logic
  final tailWidth = 20.0; // Width of the tail at the base
  final tailHeight = MapBubbleWidget.arrowHeight;
  final centerX = w / 2;
  final bottomY = h - tailHeight;

  // Draw right side of the bottom edge until tail start
  path.lineTo(centerX + tailWidth, bottomY);

  // Curve down to the tip
  // Control point is slightly inward and down to create a smooth curve
  path.quadraticBezierTo(
    centerX + tailWidth * 0.4,
    bottomY, // Control point 1: Smooth start
    centerX,
    h, // Target point: Tip
  );

  // Curve up from the tip
  path.quadraticBezierTo(
    centerX - tailWidth * 0.4,
    bottomY, // Control point 2: Smooth end
    centerX - tailWidth,
    bottomY, // Target point: End of tail on the left
  );

  // Draw left side of the bottom edge
  path.lineTo(r, bottomY);
  path.arcToPoint(Offset(0, bottomY - r), radius: Radius.circular(r));
  path.lineTo(0, r);
  path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
  return path;
}
