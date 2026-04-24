import 'package:flutter/material.dart';

/// 屏幕正中央的短暂 toast（fade in → 停留 → fade out → 自动移除）。
///
/// 用 [OverlayEntry] 而非 SnackBar，以摆脱"SnackBar 被 Scaffold 强制底部对齐"
/// 的限制，可精确显示在屏幕垂直中央。
///
/// 视觉沿用主页发布成功 SnackBar 的风格：绿底、白字、check 图标、粗圆角卡片。
///
/// - [duration] 总时长（含 fade 动画）。默认 1400ms：200ms fadeIn + 1000ms 停留 + 200ms fadeOut。
/// - 不阻塞手势（`IgnorePointer` 包裹）；重复调用会叠加显示，调用方自己保证不高频触发。
void showCenterToast(
  BuildContext context, {
  required String message,
  IconData icon = Icons.check_circle,
  Color background = const Color(0xFF22C55E), // green-500，同原 SnackBar
  Duration duration = const Duration(milliseconds: 1400),
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _CenterToast(
      message: message,
      icon: icon,
      background: background,
      duration: duration,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _CenterToast extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color background;
  final Duration duration;
  final VoidCallback onDone;

  const _CenterToast({
    required this.message,
    required this.icon,
    required this.background,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_CenterToast> createState() => _CenterToastState();
}

class _CenterToastState extends State<_CenterToast> {
  static const _fadeDuration = Duration(milliseconds: 200);

  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // Fade in — 首帧挂载后触发，拿到从 0→1 的过渡
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _opacity = 1.0);
    });
    // Fade out — 在总时长结束前 200ms 开始
    final visibleEnd = widget.duration - _fadeDuration;
    Future.delayed(visibleEnd.isNegative ? Duration.zero : visibleEnd, () {
      if (!mounted) return;
      setState(() => _opacity = 0.0);
    });
    // 移除 overlay entry
    Future.delayed(widget.duration, widget.onDone);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: _fadeDuration,
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: widget.background,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
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
}
