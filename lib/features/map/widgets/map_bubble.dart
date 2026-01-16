import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/post_model.dart';
import '../../../presentation/providers/post_provider.dart';

// 核心组件：动态气泡
class MapBubbleWidget extends StatelessWidget {
  static const double collapsedSize = 60.0;
  static const double expandedSize = 280.0;
  static const double expandedHeightFactor = 1.2;
  static const double expandedHeight = expandedSize * expandedHeightFactor;
  static const double arrowHeight = 20.0;

  final bool isExpanded;
  final VoidCallback onTap;
  final double scaleFactor;
  final PostModel post;

  const MapBubbleWidget({
    super.key,
    required this.isExpanded,
    required this.onTap,
    this.scaleFactor = 1.0,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    final double baseSize = isExpanded ? expandedSize : collapsedSize;
    final double bubbleHeight = isExpanded ? expandedHeight : collapsedSize;

    return GestureDetector(
      onTap: onTap,
      child: Align(
        alignment: Alignment.bottomCenter,
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
                CustomPaint(
                  size: Size(baseSize, bubbleHeight),
                  painter: BubblePainter(
                    color: const Color.fromARGB(255, 15, 245, 191),
                    isExpanded: isExpanded,
                  ),
                ),
                if (scaleFactor >= 0.5)
                  ClipPath(
                    clipper: BubbleClipper(isExpanded: isExpanded),
                    child: SizedBox.expand(
                      child: isExpanded
                          ? _buildExpandedContent(context)
                          : _buildCollapsedContent(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 5), // Center inside the circle
        child: CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(post.user.avatarUrl),
          onBackgroundImageError: (_, __) {},
        ),
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final imageUrl = post.imageUrls.isNotEmpty
        ? post.imageUrls[0]
        : 'https://picsum.photos/300/300';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 35),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Like and Favorite buttons on both sides
          Consumer<PostProvider>(
            builder: (context, postProvider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Like button on left
                    GestureDetector(
                      onTap: () {
                        postProvider.toggleLike(post.id);
                      },
                      child: Icon(
                        post.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 24,
                        color: post.isLiked ? Colors.red : Colors.black54,
                      ),
                    ),
                    // Favorite button on right
                    GestureDetector(
                      onTap: () {
                        postProvider.toggleFavorite(post.id);
                      },
                      child: Icon(
                        post.isFavorited ? Icons.star : Icons.star_border,
                        size: 24,
                        color: post.isFavorited ? Colors.amber : Colors.black54,
                      ),
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
      ..moveTo(w / 2 - 8, h - 15)
      ..lineTo(w / 2, h)
      ..lineTo(w / 2 + 8, h - 15)
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
  path.lineTo(w / 2 + 15, h - MapBubbleWidget.arrowHeight);
  path.lineTo(w / 2, h);
  path.lineTo(w / 2 - 15, h - MapBubbleWidget.arrowHeight);
  path.lineTo(r, h - MapBubbleWidget.arrowHeight);
  path.arcToPoint(
    Offset(0, h - MapBubbleWidget.arrowHeight - r),
    radius: Radius.circular(r),
  );
  path.lineTo(0, r);
  path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
  return path;
}
