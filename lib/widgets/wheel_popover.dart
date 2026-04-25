import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 从 [anchorKey] 对应的 widget 位置右侧（或左侧）浮出一个 iOS 风格滚轮 picker。
///
/// - 毛玻璃圆角卡片 + 软阴影；点外部关闭（带淡出）
/// - 滚动时实时回调 [onChanged]，没有"确定"按钮
/// - 右侧空间不够自动翻到左侧；垂直方向以 anchor 中心对齐并 clamp 到屏幕内
///
/// 典型用途：把一个"pill chip → 展开滚轮"的交互从 inline 改为 floating popover，
/// 不再挤占原 layout 空间。
Future<void> showWheelPopover({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<String> options,
  required String selected,
  required ValueChanged<String> onChanged,
  double width = 180,
  double height = 160,
  Color accent = const Color(0xFF3FAAF0),
}) async {
  final overlayCtx = Overlay.of(context);
  final anchorCtx = anchorKey.currentContext;
  if (anchorCtx == null) return;

  final box = anchorCtx.findRenderObject() as RenderBox?;
  if (box == null || !box.attached) return;

  final anchorPos = box.localToGlobal(Offset.zero);
  final anchorSize = box.size;
  final screenSize = MediaQuery.of(context).size;
  final topInset = MediaQuery.of(context).padding.top;
  final bottomInset = MediaQuery.of(context).padding.bottom;

  const gap = 8.0;
  const edgePad = 16.0;

  // 优先显示在 anchor 右侧；右侧不够就翻到左侧
  final rightLeft = anchorPos.dx + anchorSize.width + gap;
  final leftLeft = anchorPos.dx - width - gap;
  final flipLeft = rightLeft + width > screenSize.width - edgePad;
  final popoverLeft = flipLeft ? leftLeft : rightLeft;

  // 垂直对齐 anchor 中心，夹在屏幕内
  final anchorCenterY = anchorPos.dy + anchorSize.height / 2;
  var popoverTop = anchorCenterY - height / 2;
  popoverTop = popoverTop.clamp(
    topInset + edgePad,
    screenSize.height - bottomInset - height - edgePad,
  );

  // 如果向左弹但屏幕左边也不够（极罕见），夹一下
  final maxLeft = screenSize.width - width - edgePad;
  final finalLeft = popoverLeft.clamp(edgePad, maxLeft);

  final stateKey = GlobalKey<_WheelPopoverState>();
  late OverlayEntry entry;

  Future<void> close() async {
    final state = stateKey.currentState;
    if (state != null) await state.animateOut();
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _WheelPopover(
      key: stateKey,
      left: finalLeft,
      top: popoverTop,
      width: width,
      height: height,
      growFromLeft: !flipLeft,
      options: options,
      selected: selected,
      accent: accent,
      onChanged: onChanged,
      onDismiss: close,
    ),
  );

  overlayCtx.insert(entry);
}

class _WheelPopover extends StatefulWidget {
  final double left;
  final double top;
  final double width;
  final double height;

  /// true = 弹在 anchor 右侧，Transform 原点用 centerLeft（从左往右放大）。
  /// false = 弹在左侧，原点用 centerRight。
  final bool growFromLeft;

  final List<String> options;
  final String selected;
  final Color accent;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onDismiss;

  const _WheelPopover({
    super.key,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.growFromLeft,
    required this.options,
    required this.selected,
    required this.accent,
    required this.onChanged,
    required this.onDismiss,
  });

  @override
  State<_WheelPopover> createState() => _WheelPopoverState();
}

class _WheelPopoverState extends State<_WheelPopover> {
  static const _animDuration = Duration(milliseconds: 180);

  double _opacity = 0.0;
  double _scale = 0.94;

  @override
  void initState() {
    super.initState();
    // Pop-in 动画：首帧挂载后触发 0→1 过渡
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _opacity = 1.0;
        _scale = 1.0;
      });
    });
  }

  /// 给外部触发关闭动画用；动画结束后 Future 完成，调用方再 remove overlay。
  Future<void> animateOut() async {
    if (!mounted) return;
    setState(() {
      _opacity = 0.0;
      _scale = 0.94;
    });
    await Future<void>.delayed(_animDuration);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scrim：透明全屏点击层，点外部关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onDismiss(),
          ),
        ),
        // Popover 本体
        Positioned(
          left: widget.left,
          top: widget.top,
          width: widget.width,
          height: widget.height,
          child: AnimatedOpacity(
            duration: _animDuration,
            curve: Curves.easeOut,
            opacity: _opacity,
            child: AnimatedScale(
              duration: _animDuration,
              curve: Curves.easeOutCubic,
              scale: _scale,
              alignment: widget.growFromLeft
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(220),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withAlpha(130),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(38),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: widget.options
                              .indexOf(widget.selected)
                              .clamp(0, widget.options.length - 1),
                        ),
                        itemExtent: 36,
                        backgroundColor: Colors.transparent,
                        selectionOverlay:
                            CupertinoPickerDefaultSelectionOverlay(
                              background: widget.accent.withAlpha(30),
                            ),
                        onSelectedItemChanged: (index) =>
                            widget.onChanged(widget.options[index]),
                        children: widget.options
                            .map(
                              (o) => Center(
                                child: Text(
                                  o,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
