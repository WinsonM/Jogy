import 'package:flutter/material.dart';

class GlassBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 获取设备底部安全区域高度，兼容不同机型
        final double bottomSafeArea = MediaQuery.of(context).padding.bottom;
        final double bottomPadding = bottomSafeArea + 8;

        // 计算导航栏内部可用宽度
        final double containerPadding = 8 * 2; // horizontal padding
        final double itemMargin = 4 * 2; // margin per item
        final double totalInnerWidth =
            constraints.maxWidth - 32 - containerPadding; // 32 = outer padding

        // flex 比例: 选中项 2, 未选中项 1, 总共 = 2 + 1 + 1 = 4
        final double flexUnit = totalInnerWidth / 4;
        final double selectedItemWidth = flexUnit * 2;
        final double unselectedItemWidth = flexUnit * 1;

        // 计算选中指示器的位置
        double indicatorLeft = 0;
        for (int i = 0; i < currentIndex; i++) {
          indicatorLeft += (i == currentIndex)
              ? selectedItemWidth
              : unselectedItemWidth;
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Stack(
                children: [
                  // 滑动选中指示器背景
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    left: indicatorLeft,
                    top: 0,
                    bottom: 0,
                    width: selectedItemWidth,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                  ),
                  // 导航项 Row - 使用透明背景
                  Row(
                    children: [
                      _buildNavItem(
                        index: 0,
                        filledIcon: Icons.home,
                        outlinedIcon: Icons.home_outlined,
                        label: '主页',
                        isSelected: currentIndex == 0,
                      ),
                      _buildNavItem(
                        index: 1,
                        filledIcon: Icons.chat_bubble,
                        outlinedIcon: Icons.chat_bubble_outline,
                        label: '消息',
                        isSelected: currentIndex == 1,
                      ),
                      // "我的"按钮 - 点击时不切换页面，保持禁用状态
                      _buildNavItem(
                        index: -1, // 使用 -1 表示不参与页面切换
                        filledIcon: Icons.person,
                        outlinedIcon: Icons.person_outline,
                        label: '我的',
                        isSelected: false, // 永远不选中
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData filledIcon,
    required IconData outlinedIcon,
    required String label,
    required bool isSelected,
  }) {
    // 选中时用实心图标，未选中时用空心图标
    const itemColor = Colors.black;
    final icon = isSelected ? filledIcon : outlinedIcon;

    return Expanded(
      flex: isSelected ? 2 : 1,
      child: GestureDetector(
        onTap: index >= 0 ? () => onTap(index) : null, // index < 0 时不响应点击
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // 背景由 Stack 中的指示器提供，这里透明
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标带弹性动画
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: isSelected ? 1.1 : 1.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Icon(icon, size: 24, color: itemColor),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
