import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 网格气泡背景 Widget
///
/// 蓝色气泡呈动态方形网格排列，从右下角向左上角依次膨胀再缩回，形成波浪动画。
/// 包含漂移 (Drifting) 效果，使整体画面具有有机的浮动感。
class GridBubbleBackground extends StatefulWidget {
  /// 气泡列数 (行数将根据屏幕高度自动计算以保持正方形)
  final int columns;

  /// 气泡基础半径
  final double baseRadius;

  /// 膨胀时的最大倍率
  final double maxScale;

  /// 波浪动画周期 (秒)
  final double waveDuration;

  /// 漂移幅度 (像素)
  final double driftAmplitude;

  /// 气泡颜色
  final Color bubbleColor;

  /// 背景颜色
  final Color backgroundColor;

  /// 是否处于 focus 状态 (输入框聚焦时，动画变慢)
  final bool isFocused;

  /// 子组件
  final Widget? child;

  const GridBubbleBackground({
    super.key,
    this.columns = 10,
    this.baseRadius = 20.0,
    this.maxScale = 1.6,
    this.waveDuration = 3.0,
    this.driftAmplitude = 5.0,
    this.bubbleColor = const Color(0xFF5B9BD5),
    this.backgroundColor = const Color(0xFFF5F5F7),
    this.isFocused = false,
    this.child,
  });

  @override
  State<GridBubbleBackground> createState() => GridBubbleBackgroundState();
}

class GridBubbleBackgroundState extends State<GridBubbleBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.waveDuration * 1000).toInt()),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          // 气泡网格层
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _GridBubblePainter(
                  columns: widget.columns,
                  baseRadius: widget.baseRadius,
                  maxScale: widget.maxScale,
                  driftAmplitude: widget.driftAmplitude,
                  progress: _controller.value,
                  bubbleColor: widget.bubbleColor,
                  speedMultiplier: widget.isFocused ? 0.3 : 1.0,
                ),
                size: Size.infinite,
              );
            },
          ),

          // 子组件
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

/// 网格气泡绘制器
class _GridBubblePainter extends CustomPainter {
  final int columns;
  final double baseRadius;
  final double maxScale;
  final double driftAmplitude;
  final double progress;
  final Color bubbleColor;
  final double speedMultiplier;

  _GridBubblePainter({
    required this.columns,
    required this.baseRadius,
    required this.maxScale,
    required this.driftAmplitude,
    required this.progress,
    required this.bubbleColor,
    required this.speedMultiplier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 根据宽度和列数计算正方形格子的边长
    final cellSize = size.width / columns;

    // 2. 根据高度动态计算需要的行数 (向上取整以覆盖全屏)
    final rows = (size.height / cellSize).ceil();

    // 3. 计算垂直方向的居中偏移
    final verticalOffset = (size.height - rows * cellSize) / 2;

    // 为了防止碰撞，最大半径不能超过格子大小的一半
    final maxAllowedRadius = cellSize / 2.0;

    // 对角线最大距离 (用于计算波浪相位)
    final maxDiagonal = (rows - 1) + (columns - 1).toDouble();

    // 每一帧的时间因子 (0 ~ 2pi)
    final time = progress * 2 * math.pi;

    // 循环范围扩大，防止从边缘漂移时出现空隙
    // 从 -1 到 count (实际上是 count + 1 行/列)
    for (int row = -1; row <= rows; row++) {
      for (int col = -1; col <= columns; col++) {
        // 气泡基础中心位置 (网格中心)
        final gridCenterX = cellSize * (col + 0.5);
        final gridCenterY = verticalOffset + cellSize * (row + 0.5);

        // --- 漂移逻辑 (Drifting) ---
        // 使用 row/col 作为相位差，让每个点漂移轨迹不同
        final driftX = math.sin(time + row * 0.5 + col * 0.3) * driftAmplitude;
        final driftY = math.cos(time + row * 0.3 + col * 0.5) * driftAmplitude;

        final centerX = gridCenterX + driftX;
        final centerY = gridCenterY + driftY;

        // --- 波浪逻辑 ---
        // 归一化距离计算需要考虑负索引，取绝对值以获得对称波浪或简单的 clamp
        // 这里为了保持波浪方向的一致性，仍然使用原始坐标逻辑，但限制范围
        final effectiveRow = row.clamp(0, rows - 1);
        final effectiveCol = col.clamp(0, columns - 1);
        final diagonalDistance =
            (rows - 1 - effectiveRow) + (columns - 1 - effectiveCol).toDouble();
        final normalizedDistance = diagonalDistance / maxDiagonal;

        // 计算该气泡的相位偏移
        final phaseOffset = normalizedDistance * 0.8;

        // 计算当前气泡的动画相位
        final bubbleProgress = (progress + phaseOffset) % 1.0;

        // 使用 sin 曲线创建膨胀-收缩效果
        final scaleFactor =
            1.0 + (maxScale - 1.0) * math.sin(bubbleProgress * math.pi);

        // 基础半径如果太大，缩放后可能会碰撞，这里进行限制
        // 注意：漂移可能会导致轻微碰撞，但因为是动态的且幅度小，视觉上可以接受
        double radius = baseRadius * scaleFactor;
        if (radius > maxAllowedRadius) {
          radius = maxAllowedRadius;
        }

        // 透明度随膨胀变化
        final opacity = 0.3 + 0.4 * math.sin(bubbleProgress * math.pi);

        // 绘制气泡 - 纯色，无高光
        final paint = Paint()
          ..color = bubbleColor.withAlpha((opacity * 255).toInt())
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(centerX, centerY), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridBubblePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.speedMultiplier != speedMultiplier ||
        oldDelegate.columns != columns;
  }
}
