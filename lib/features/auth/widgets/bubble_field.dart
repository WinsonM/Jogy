import 'dart:math' as math;
import 'dart:ui';

import 'bubble_particle.dart';

/// 气泡质量等级
enum BubbleQuality {
  low, // 低：30 粒子，无模糊
  medium, // 中：60 粒子，轻度模糊
  high, // 高：90 粒子，全效果
}

/// 气泡场控制器
///
/// 负责管理粒子的生成 (spawn)、更新 (update)、回收 (recycle)。
/// 使用粒子池复用对象，避免频繁创建 GC。
class BubbleField {
  /// 配置参数
  final int maxParticles;
  final double spawnRate; // 每秒生成数
  final double minRadius;
  final double maxRadius;
  final double baseSpeed;
  final double speedJitter;
  final double lifespanMin;
  final double lifespanMax;
  final Offset direction; // 归一化漂移方向
  final Offset sourcePoint; // 源点 (相对坐标 0-1)

  /// 粒子池
  late List<BubbleParticle> _particles;

  /// 累积的 spawn 计时器
  double _spawnAccumulator = 0.0;

  /// 波浪相位计数器 (用于 "鳞次栉比" 效果)
  double _wavePhase = 0.0;

  final math.Random _random = math.Random();

  /// 速度倍率 (focus 时变慢)
  double speedMultiplier = 1.0;

  /// 透明度倍率 (focus 时变暗)
  double opacityMultiplier = 1.0;

  /// burst 模式持续时间
  double _burstRemaining = 0.0;

  BubbleField({
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
  }) {
    // 预分配粒子池
    _particles = List.generate(
      maxParticles,
      (_) => BubbleParticle()..age = double.infinity, // 初始为死亡状态
    );
  }

  /// 获取所有存活粒子
  Iterable<BubbleParticle> get aliveParticles =>
      _particles.where((p) => p.isAlive);

  /// 触发 burst 效果
  void triggerBurst({double duration = 0.6}) {
    _burstRemaining = duration;
  }

  /// 每帧更新
  ///
  /// [dt] 帧间隔 (秒)
  /// [screenSize] 屏幕尺寸
  void update(double dt, Size screenSize) {
    // 处理 burst 模式
    final isBursting = _burstRemaining > 0;
    if (isBursting) {
      _burstRemaining -= dt;
    }

    // burst 时提高 spawn 速率和速度
    final effectiveSpawnRate = isBursting ? spawnRate * 3.0 : spawnRate;
    final effectiveSpeedMult = isBursting
        ? speedMultiplier * 1.5
        : speedMultiplier;

    // 更新波浪相位
    _wavePhase += dt * 2.0;

    // 更新所有粒子
    for (final particle in _particles) {
      if (particle.isAlive) {
        particle.update(dt, speedMultiplier: effectiveSpeedMult);
      }
    }

    // 生成新粒子
    _spawnAccumulator += dt * effectiveSpawnRate;
    while (_spawnAccumulator >= 1.0) {
      _spawnAccumulator -= 1.0;
      _spawnParticle(screenSize);
    }
  }

  /// 生成一个新粒子
  void _spawnParticle(Size screenSize) {
    // 找一个死亡的粒子复用
    final deadParticle = _particles.cast<BubbleParticle?>().firstWhere(
      (p) => !p!.isAlive,
      orElse: () => null,
    );

    if (deadParticle == null) return; // 粒子池已满

    // 计算源点位置
    final sourceX = screenSize.width * sourcePoint.dx;
    final sourceY = screenSize.height * sourcePoint.dy;

    // "鳞次栉比" 效果：使用波浪偏移 + 扇形随机分布
    final waveOffset = _wavePhase + _random.nextDouble() * 0.5;

    // 在扇形区域内随机生成位置 (120° 扇区)
    final fanAngle = math.pi * 2 / 3; // 120°
    final baseAngle = math.pi + math.pi / 6; // 朝向左上
    final angle = baseAngle + (_random.nextDouble() - 0.5) * fanAngle;
    final spawnRadius = _random.nextDouble() * 30 + 10; // 10-40px 散布

    final spawnX = sourceX + math.cos(angle) * spawnRadius;
    final spawnY = sourceY + math.sin(angle) * spawnRadius;

    // 计算速度 (方向 + 扰动)
    final speed = baseSpeed + (_random.nextDouble() - 0.5) * 2 * speedJitter;
    final dirJitter = Offset(
      (_random.nextDouble() - 0.5) * 0.2,
      (_random.nextDouble() - 0.5) * 0.2,
    );
    final normalizedDir = _normalize(direction + dirJitter);
    final velocity = normalizedDir * speed;

    // 随机半径和生命周期
    final radius = minRadius + _random.nextDouble() * (maxRadius - minRadius);
    final lifespan =
        lifespanMin + _random.nextDouble() * (lifespanMax - lifespanMin);

    deadParticle.reset(
      position: Offset(spawnX, spawnY),
      velocity: velocity,
      targetRadius: radius,
      lifespan: lifespan,
      waveOffset: waveOffset,
    );
  }

  Offset _normalize(Offset offset) {
    final length = offset.distance;
    if (length == 0) return Offset.zero;
    return offset / length;
  }
}
