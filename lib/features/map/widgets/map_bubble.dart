import 'package:flutter/material.dart';
import '../../../data/models/post_model.dart';

// 核心组件：动态气泡
class MapBubbleWidget extends StatelessWidget {
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
    final double baseSize = isExpanded ? 280.0 : 60.0;

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Transform.scale(
          scale: scaleFactor,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            width: baseSize,
            height: isExpanded ? baseSize * 1.2 : baseSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(baseSize, isExpanded ? baseSize * 1.2 : baseSize),
                  painter: BubblePainter(
                    color: const Color.fromARGB(255, 15, 245, 191),
                    isExpanded: isExpanded,
                  ),
                ),
                // Only show content if scale is large enough
                if (scaleFactor >= 0.5)
                  isExpanded
                      ? _buildExpandedContent()
                      : _buildCollapsedContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return CircleAvatar(
      radius: 20,
      backgroundImage: NetworkImage(post.user.avatarUrl),
      onBackgroundImageError: (_, __) {},
    );
  }

  Widget _buildExpandedContent() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Icon(
                post.isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                size: 20,
                color: post.isLiked ? Colors.blue : Colors.black54,
              ),
              Icon(Icons.favorite_border, size: 20, color: Colors.black54),
              Icon(Icons.star_border, size: 20, color: Colors.black54),
            ],
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

    final path = Path();
    double w = size.width;
    double h = size.height;
    double arrowH = 20.0;
    double r = isExpanded ? 24.0 : w / 2;

    if (!isExpanded) {
      // Draw shadow for circle
      final circlePath = Path()
        ..addOval(
          Rect.fromCircle(center: Offset(w / 2, h / 2 - 5), radius: w / 2 - 5),
        );
      canvas.drawShadow(circlePath, Colors.black.withOpacity(0.15), 10.0, true);

      canvas.drawCircle(Offset(w / 2, h / 2 - 5), w / 2 - 5, paint);

      // Draw shadow for arrow
      Path arrow = Path();
      arrow.moveTo(w / 2 - 8, h - 15);
      arrow.lineTo(w / 2, h);
      arrow.lineTo(w / 2 + 8, h - 15);
      arrow.close();
      canvas.drawShadow(arrow, Colors.black.withOpacity(0.15), 10.0, true);
      canvas.drawPath(arrow, paint);
      return;
    }

    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    path.lineTo(w, h - arrowH - r);
    path.arcToPoint(Offset(w - r, h - arrowH), radius: Radius.circular(r));
    path.lineTo(w / 2 + 15, h - arrowH);
    path.lineTo(w / 2, h);
    path.lineTo(w / 2 - 15, h - arrowH);
    path.lineTo(r, h - arrowH);
    path.arcToPoint(Offset(0, h - arrowH - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));

    // Draw shadow for expanded bubble
    canvas.drawShadow(path, Colors.black.withOpacity(0.15), 10.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
