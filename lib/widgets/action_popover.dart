import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 一个 glass-style 的垂直动作菜单（替代 Material `PopupMenuButton`）。
///
/// 视觉：毛玻璃 + 圆角 16 + 软阴影 + pop-in 缩放/淡入动画。点外部关闭。
/// 对齐：以 [anchorKey] 对应 widget 的右下为锚点，菜单出现在 anchor 下方右对齐。
/// 空间不够时自动翻到 anchor 上方；横向也会 clamp 到屏幕内边距 16。
///
/// 与 `wheel_popover.dart` 同源审美，保持全 app 的弹层风格一致。
///
/// 用法：
/// ```dart
/// final key = GlobalKey();
/// // ...
/// IconButton(key: key, icon: ..., onPressed: () {
///   showActionPopover(
///     context: context,
///     anchorKey: key,
///     items: [
///       ActionPopoverItem(label: '编辑', icon: Icons.edit_outlined,
///         onTap: () => _openEditPage()),
///       ActionPopoverItem(label: '删除', icon: Icons.delete_outline,
///         destructive: true, onTap: () => _confirmDelete()),
///     ],
///   );
/// });
/// ```
class ActionPopoverItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// 红色高亮（删除 / 退出登录之类的破坏性操作）。
  final bool destructive;

  const ActionPopoverItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });
}

Future<void> showActionPopover({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<ActionPopoverItem> items,
  double width = 156,
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

  // 每行 44px + 上下各 6px padding；按 item 数动态算高度。
  //
  // 这里留 2px slack：不同设备 / 字体 fallback 下中文 Text 的实际 glyph metrics
  // 会有亚像素取整，刚好等于理论高度时 debug 模式可能出现
  // "BOTTOM OVERFLOWED BY 1.00 PIXELS"。
  const rowHeight = 44.0;
  const verticalPad = 6.0;
  const layoutSlack = 2.0;
  final height = items.length * rowHeight + verticalPad * 2 + layoutSlack;

  const gap = 6.0;
  const edgePad = 16.0;

  // 默认弹在 anchor 下方；下方空间不够时翻到上方
  final belowTop = anchorPos.dy + anchorSize.height + gap;
  final aboveTop = anchorPos.dy - height - gap;
  final flipUp = belowTop + height > screenSize.height - bottomInset - edgePad;
  final popoverTop = flipUp ? aboveTop : belowTop;

  // 横向：菜单右边缘对齐 anchor 右边缘（更"出自三个点"），左侧不够再回退到 edgePad
  final desiredLeft = anchorPos.dx + anchorSize.width - width;
  final maxLeft = screenSize.width - width - edgePad;
  final finalLeft = desiredLeft.clamp(edgePad, maxLeft);

  // 垂直 clamp 防出屏（极端尺寸）
  final clampedTop = popoverTop.clamp(
    topInset + edgePad,
    screenSize.height - bottomInset - height - edgePad,
  );

  final stateKey = GlobalKey<_ActionPopoverState>();
  late OverlayEntry entry;

  Future<void> close() async {
    final state = stateKey.currentState;
    if (state != null) await state.animateOut();
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _ActionPopover(
      key: stateKey,
      left: finalLeft,
      top: clampedTop,
      width: width,
      height: height,
      growFromTop: !flipUp,
      items: items,
      onDismiss: close,
    ),
  );

  overlayCtx.insert(entry);
}

class _ActionPopover extends StatefulWidget {
  final double left;
  final double top;
  final double width;
  final double height;

  /// true = 弹在 anchor 下方，Transform 原点用 topRight（从右上往下展开）。
  /// false = 弹在上方，原点用 bottomRight。
  final bool growFromTop;

  final List<ActionPopoverItem> items;
  final Future<void> Function() onDismiss;

  const _ActionPopover({
    super.key,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.growFromTop,
    required this.items,
    required this.onDismiss,
  });

  @override
  State<_ActionPopover> createState() => _ActionPopoverState();
}

class _ActionPopoverState extends State<_ActionPopover> {
  static const _animDuration = Duration(milliseconds: 180);

  double _opacity = 0.0;
  double _scale = 0.94;

  @override
  void initState() {
    super.initState();
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
        // 全屏透明 scrim：点外部关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onDismiss(),
          ),
        ),
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
              alignment: widget.growFromTop
                  ? Alignment.topRight
                  : Alignment.bottomRight,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final item in widget.items)
                              _PopoverRow(
                                item: item,
                                onTap: () async {
                                  // 关闭动画结束后再触发回调，避免动作里 push 路由
                                  // 时 popover 的 setState 还在跑导致警告。
                                  await widget.onDismiss();
                                  item.onTap();
                                },
                              ),
                          ],
                        ),
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

class _PopoverRow extends StatelessWidget {
  final ActionPopoverItem item;
  final VoidCallback onTap;

  const _PopoverRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = item.destructive
        ? const Color(0xFFE53935) // 红色 destructive
        : Colors.black87;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
