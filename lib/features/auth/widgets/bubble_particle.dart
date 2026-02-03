import 'package:flutter/animation.dart';

/// 气泡粒子生命周期阶段
enum BubblePhase {
  spawning, // 出生放大
  drifting, // 漂移中
  fading, // 消失中
}

/// 气泡粒子数据类
///
/// 每个粒子包含位置、速度、大小、透明度、生命周期等属性。
/// 使用 [reset] 方法复用粒子，避免频繁创建对象。
class BubbleParticle {
  /// 当前位置
  Offset position;

  /// 移动速度 (像素/秒)
  Offset velocity;

  /// 目标半径
  double targetRadius;

  /// 当前半径 (动画中)
  double currentRadius;

  /// 当前透明度 (0.0 - 1.0)
  double opacity;

  /// 已存活时间 (秒)
  double age;

  /// 总生命周期 (秒)
  double lifespan;

  /// 当前阶段
  BubblePhase phase;

  /// 是否存活
  bool get isAlive => age < lifespan;

  /// 生命周期进度 (0.0 - 1.0)
  double get progress => (age / lifespan).clamp(0.0, 1.0);

  /// 用于"鳞次栉比"效果的波浪相位偏移
  double waveOffset;

  BubbleParticle({
    this.position = Offset.zero,
    this.velocity = Offset.zero,
    this.targetRadius = 20.0,
    this.currentRadius = 0.0,
    this.opacity = 0.0,
    this.age = 0.0,
    this.lifespan = 4.0,
    this.phase = BubblePhase.spawning,
    this.waveOffset = 0.0,
  });

  /// 重置粒子状态以复用
  void reset({
    required Offset position,
    required Offset velocity,
    required double targetRadius,
    required double lifespan,
    required double waveOffset,
  }) {
    this.position = position;
    this.velocity = velocity;
    this.targetRadius = targetRadius;
    this.lifespan = lifespan;
    this.waveOffset = waveOffset;
    currentRadius = targetRadius * 0.2; // 初始为目标的 20%
    opacity = 0.0;
    age = 0.0;
    phase = BubblePhase.spawning;
  }

  /// 更新粒子状态
  ///
  /// [dt] 距上一帧的时间间隔 (秒)
  /// [speedMultiplier] 速度倍率 (用于 focus 变慢效果)
  void update(double dt, {double speedMultiplier = 1.0}) {
    age += dt;

    // 更新位置
    position += velocity * dt * speedMultiplier;

    // 根据生命周期阶段更新半径和透明度
    final spawnDuration = lifespan * 0.15; // 前 15% 放大
    final fadeDuration = lifespan * 0.20; // 后 20% 消失

    if (age < spawnDuration) {
      // Spawning: 0.2x -> 1.0x, opacity 0 -> 1
      phase = BubblePhase.spawning;
      final t = age / spawnDuration;
      final eased = Curves.easeOutCubic.transform(t);
      currentRadius = targetRadius * (0.2 + 0.8 * eased);
      opacity = eased * 0.6; // 最大透明度 0.6
    } else if (age > lifespan - fadeDuration) {
      // Fading: opacity -> 0
      phase = BubblePhase.fading;
      final t = (age - (lifespan - fadeDuration)) / fadeDuration;
      final eased = Curves.easeInCubic.transform(t);
      opacity = 0.6 * (1.0 - eased);
    } else {
      // Drifting: 正常漂移
      phase = BubblePhase.drifting;
      currentRadius = targetRadius;
      opacity = 0.6;
    }
  }
}
