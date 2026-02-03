import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'bubble_field.dart';
import 'bubble_particle.dart';

/// 气泡背景 Widget
///
/// 使用 CustomPainter + Ticker 实现高性能气泡动画。
/// 支持交互效果：burst (点击登录) 和 focus (输入框聚焦)。
class BubbleBackground extends StatefulWidget {
  /// 最大粒子数
  final int maxParticles;

  /// 每秒生成数
  final double spawnRate;

  /// 最小半径
  final double minRadius;

  /// 最大半径
  final double maxRadius;

  /// 基础速度 (像素/秒)
  final double baseSpeed;

  /// 速度扰动范围
  final double speedJitter;

  /// 最短生命周期 (秒)
  final double lifespanMin;

  /// 最长生命周期 (秒)
  final double lifespanMax;

  /// 漂移方向 (归一化)
  final Offset direction;

  /// 源点位置 (相对坐标 0-1)
  final Offset sourcePoint;

  /// 是否启用模糊遮罩
  final bool enableBlurOverlay;

  /// 遮罩透明度
  final double overlayOpacity;

  /// 质量等级
  final BubbleQuality quality;

  /// 背景渐变色
  final List<Color> gradientColors;

  /// 是否处于 focus 状态 (输入框聚焦时)
  final bool isFocused;

  /// 子组件
  final Widget? child;

  const BubbleBackground({
    super.key,
    this.maxParticles = 60,
    this.spawnRate = 3.0,
    this.minRadius = 8.0,
    this.maxRadius = 42.0,
    this.baseSpeed = 50.0,
    this.speedJitter = 15.0,
    this.lifespanMin = 3.0,
    this.lifespanMax = 6.0,
    this.direction = const Offset(-0.7, -0.7),
    this.sourcePoint = const Offset(0.92, 0.90),
    this.enableBlurOverlay = true,
    this.overlayOpacity = 0.25,
    this.quality = BubbleQuality.medium,
    this.gradientColors = const [Color(0xFF1a1a2e), Color(0xFF16213e)],
    this.isFocused = false,
    this.child,
  });

  @override
  State<BubbleBackground> createState() => BubbleBackgroundState();
}

class BubbleBackgroundState extends State<BubbleBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late BubbleField _bubbleField;
  late Ticker _ticker;
  Duration _lastTickTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 根据质量等级调整参数
    final effectiveMaxParticles = _getMaxParticles();
    final effectiveSpawnRate = _getSpawnRate();

    _bubbleField = BubbleField(
      maxParticles: effectiveMaxParticles,
      spawnRate: effectiveSpawnRate,
      minRadius: widget.minRadius,
      maxRadius: widget.maxRadius,
      baseSpeed: widget.baseSpeed,
      speedJitter: widget.speedJitter,
      lifespanMin: widget.lifespanMin,
      lifespanMax: widget.lifespanMax,
      direction: widget.direction,
      sourcePoint: widget.sourcePoint,
    );

    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  int _getMaxParticles() {
    switch (widget.quality) {
      case BubbleQuality.low:
        return 30;
      case BubbleQuality.medium:
        return 60;
      case BubbleQuality.high:
        return 90;
    }
  }

  double _getSpawnRate() {
    switch (widget.quality) {
      case BubbleQuality.low:
        return widget.spawnRate * 0.5;
      case BubbleQuality.medium:
        return widget.spawnRate;
      case BubbleQuality.high:
        return widget.spawnRate * 1.5;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    if (dt <= 0 || dt > 0.1) return; // 跳过异常帧

    // 处理 focus 状态
    _bubbleField.speedMultiplier = widget.isFocused ? 0.3 : 1.0;
    _bubbleField.opacityMultiplier = widget.isFocused ? 0.5 : 1.0;

    final size = MediaQuery.of(context).size;
    _bubbleField.update(dt, size);

    setState(() {});
  }

  /// 触发 burst 效果 (供外部调用)
  void triggerBurst() {
    _bubbleField.triggerBurst();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App 进入后台时暂停 ticker
    if (state == AppLifecycleState.paused) {
      _ticker.stop();
    } else if (state == AppLifecycleState.resumed) {
      _ticker.start();
      _lastTickTime = Duration.zero;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 渐变背景
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
          ),
        ),

        // 气泡层
        CustomPaint(
          painter: _BubblePainter(
            particles: _bubbleField.aliveParticles.toList(),
            opacityMultiplier: _bubbleField.opacityMultiplier,
          ),
          size: Size.infinite,
        ),

        // 模糊遮罩层
        if (widget.enableBlurOverlay && widget.quality != BubbleQuality.low)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                child: Container(
                  color: Colors.black.withAlpha(
                    (widget.overlayOpacity * 255).toInt(),
                  ),
                ),
              ),
            ),
          ),

        // 子组件
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// 气泡绘制器
class _BubblePainter extends CustomPainter {
  final List<BubbleParticle> particles;
  final double opacityMultiplier;

  _BubblePainter({required this.particles, this.opacityMultiplier = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      if (!particle.isAlive) continue;

      final effectiveOpacity = (particle.opacity * opacityMultiplier).clamp(
        0.0,
        1.0,
      );
      if (effectiveOpacity <= 0) continue;

      // 绘制气泡：带径向渐变的圆
      final center = particle.position;
      final radius = particle.currentRadius;

      // 主体渐变
      final gradient = RadialGradient(
        center: const Alignment(-0.3, -0.3), // 高光偏移
        radius: 1.0,
        colors: [
          Colors.white.withAlpha((effectiveOpacity * 255 * 0.8).toInt()),
          Colors.white.withAlpha((effectiveOpacity * 255 * 0.3).toInt()),
          Colors.white.withAlpha((effectiveOpacity * 255 * 0.1).toInt()),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, paint);

      // 高光
      final highlightPaint = Paint()
        ..color = Colors.white.withAlpha((effectiveOpacity * 255 * 0.4).toInt())
        ..style = PaintingStyle.fill;

      final highlightCenter = center + Offset(-radius * 0.25, -radius * 0.25);
      final highlightRadius = radius * 0.3;
      canvas.drawCircle(highlightCenter, highlightRadius, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) => true;
}
