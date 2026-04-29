import 'package:flutter/material.dart';

import '../../../data/models/post_model.dart';

class MapBroadcastCloudWidget extends StatelessWidget {
  static const double width = 220.0;
  static const double height = 156.0;
  static const double cloudHeight = 108.0;

  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const MapBroadcastCloudWidget({
    super.key,
    required this.post,
    required this.onLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: width,
            height: cloudHeight,
            child: CustomPaint(
              painter: _CloudPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          post.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF27313A),
                            fontSize: 14,
                            height: 1.18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CloudAction(
                          icon: post.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: post.likes > 0 ? '${post.likes}' : '',
                          color: post.isLiked
                              ? const Color(0xFFE84D4D)
                              : const Color(0xFF52616D),
                          onTap: onLike,
                        ),
                        _CloudAction(
                          icon: Icons.mode_comment_outlined,
                          label: '',
                          color: const Color(0xFF52616D),
                          onTap: onReply,
                        ),
                      ],
                    ),
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

class _CloudAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CloudAction({
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
        height: 28,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color),
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

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildCloudPath(size);
    canvas.drawShadow(path, Colors.black.withAlpha(45), 10, true);

    final paint = Paint()
      ..color = Colors.white.withAlpha(238)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = const Color(0x1A000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, borderPaint);
  }

  Path _buildCloudPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.18, h * 0.74)
      ..cubicTo(w * 0.04, h * 0.73, w * 0.03, h * 0.42, w * 0.19, h * 0.41)
      ..cubicTo(w * 0.18, h * 0.20, w * 0.42, h * 0.10, w * 0.52, h * 0.24)
      ..cubicTo(w * 0.65, h * 0.04, w * 0.92, h * 0.17, w * 0.86, h * 0.42)
      ..cubicTo(w * 1.01, h * 0.45, w * 0.98, h * 0.76, w * 0.82, h * 0.74)
      ..lineTo(w * 0.18, h * 0.74)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
