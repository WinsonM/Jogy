import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ZoomArcControl extends StatefulWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onLocationTap;

  const ZoomArcControl({
    super.key,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.onLocationTap,
    this.minZoom = 3.0,
    this.maxZoom = 18.0,
  });

  @override
  State<ZoomArcControl> createState() => _ZoomArcControlState();
}

class _ZoomArcControlState extends State<ZoomArcControl> {
  // Arc parameters

  // Start angle: -45 degrees (top-rightish if 0 is right, but coordinate system differs)
  // Flutter Canvas: 0 is right, pi/2 is down, pi is left, -pi/2 is up.
  // We want an arc in the boottom-right corner.
  // Let's say we want a 90 degree arc centered at bottom-right corner.
  // Actually the design shows accurate curve. Let's make it a generic arc segment.
  // Based on sketch: it's like a C shape or a quarter circle.
  // Let's assume it spans from -135 degrees to -45 degrees (top-left to top-right relative to center)
  // Wait, looking at the sketch, it looks like a quarter circle in the bottom-right corner,
  // but inverted? User said "arc ring".
  // Let's implement a quarter-circle arc (90 degrees) roughly from "West" to "North" relative to the button center.
  // 0 is Right. -90 (pi/-2) is Up. 180 (pi) is Left. 90 (pi/2) is Down.
  // Let's place the center of the control at bottom-right.
  // The arc should be from angle PI (180 deg) (Left) to -PI/2 (-90 deg) (Up) ?? No that's huge.
  // Let's try an arc from 180 degrees to 270 degrees (or -90).
  // Visual:
  //      |
  //   __ |
  //  /  \|
  // | O  |  <-- "O" is location button. Arc is to the left and top of it.

  // Angle range in radians
  // pi is 180 deg (Left). -pi/2 is -90 deg (Up).
  // So range is from -pi/2 to -pi. ( -90 to -180).

  double? _lastAngle;

  void _handlePanStart(Offset localPosition, Size size) {
    // Reset last angle on new pan
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    _lastAngle = math.atan2(dy, dx);
  }

  void _handlePanUpdate(Offset localPosition, Size size) {
    if (_lastAngle == null) return;

    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final currentAngle = math.atan2(dy, dx);

    // Calculate delta
    double delta = currentAngle - _lastAngle!;

    // Handle wrap-around (e.g. crossing -pi/pi boundary)
    if (delta > math.pi)
      delta -= 2 * math.pi;
    else if (delta < -math.pi)
      delta += 2 * math.pi;

    _lastAngle = currentAngle;

    // Apply sensitivity factor (weaken by 3x => 0.33)
    // Positive delta (clockwise) -> Zoom In (Increase)
    // Negative delta (counter-clockwise) -> Zoom Out (Decrease)
    // Note: In Flutter canvas coordinate:
    // Right (0) -> Down (pi/2) -> Left (pi/-pi) -> Up (-pi/2)
    // Moving from Left (-pi) to Up (-pi/2) is increasing angle (-3.14 -> -1.57).
    // So generic angle increase corresponds to clockwise movement in this quadrant.

    const double sensitivity = 0.5; // Reduced sensitivity
    // Map angle delta to zoom delta.
    // Full arc (pi/2) mapped to full zoom range was too fast.
    // Now we just map radians to arbitrary zoom units.
    // Let's say 1 radian drag = 1 zoom level * sensitivity.

    final zoomDelta = delta * sensitivity * 2.0; // Factor to tune feel

    final newZoom = (widget.currentZoom + zoomDelta).clamp(
      widget.minZoom,
      widget.maxZoom,
    );

    if (newZoom != widget.currentZoom) {
      widget.onZoomChanged(newZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Arc area
          GestureDetector(
            onPanStart: (d) =>
                _handlePanStart(d.localPosition, const Size(140, 140)),
            onPanUpdate: (d) =>
                _handlePanUpdate(d.localPosition, const Size(140, 140)),
            child: CustomPaint(
              size: const Size(140, 140),
              painter: _ZoomArcPainter(
                currentZoom: widget.currentZoom,
                minZoom: widget.minZoom,
                maxZoom: widget.maxZoom,
              ),
            ),
          ),

          // Center Location Button
          // Positioned at the geometric center of the widget (which is the center of arc curvature)
          // Since the widget size is 140x140 and arc is centered around center,
          // Button should be at center.
          Positioned(
            right: 0,
            bottom: 0,
            left: 0,
            top: 0,
            child: Center(
              child: GestureDetector(
                onTap: widget.onLocationTap,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.9,
                        ), // Less transparent for button
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.my_location,
                        color: Colors.blue[400],
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomArcPainter extends CustomPainter {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;

  _ZoomArcPainter({
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
  });

  @override
  bool hitTest(Offset position) {
    final center = Offset(140 / 2, 140 / 2); // Size is fixed at 140 in build
    final distance = (position - center).distance;
    // Radius 60, stroke 46 => range [37, 83]
    return distance >= 37 && distance <= 83;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 60.0;

    // 1. Draw Glassy Arc Background
    // Range: -pi to -pi/2
    final paintBg = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 46.0
      ..strokeCap = StrokeCap.round; // Rounded Ends

    // Path for blur
    final path = Path();
    path.addArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi,
      math.pi / 2,
    );

    // Note: MaskFilter.blur is standard blur, not backdrop blur.
    // For backdrop blur in CustomPaint, slightly complex.
    // We'll stick to color opacity + shadow for now to simulate glass.

    canvas.drawPath(
      path,
      paintBg
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5), // Glow/Shadow
    );
    // Draw actual stroke
    paintBg.maskFilter = null;
    canvas.drawPath(path, paintBg);

    // 2. Ticks
    final paintTick = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const int tickCount = 20;
    final totalAngle = math.pi / 2;
    final startAngle = -math.pi;

    for (int i = 0; i <= tickCount; i++) {
      final double t = i / tickCount;
      final double angle = startAngle + (t * totalAngle);
      final bool isMajor = i % 5 == 0;

      final double innerR = radius - 15 + (isMajor ? 0 : 5);
      final double outerR = radius + 15 - (isMajor ? 0 : 5);

      final p1 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );

      paintTick.strokeWidth = isMajor ? 2.0 : 1.0;
      canvas.drawLine(p1, p2, paintTick);
    }

    // 3. Current Level Indicator (Small triangle or line)
    // Map current zoom to angle
    final t = (currentZoom - minZoom) / (maxZoom - minZoom);
    final currentAngle = startAngle + (t * totalAngle);

    final paintIndicator = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    // Draw a small "wedge" or circle at the outer edge
    final indicatorR = radius + 4; // Center of indicator
    final cx = center.dx + indicatorR * math.cos(currentAngle);
    final cy = center.dy + indicatorR * math.sin(currentAngle);

    canvas.drawCircle(Offset(cx, cy), 6.0, paintIndicator);
  }

  @override
  bool shouldRepaint(covariant _ZoomArcPainter oldDelegate) {
    return oldDelegate.currentZoom != currentZoom;
  }
}
