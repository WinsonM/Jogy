import 'dart:ui';
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
    // Custom color requested by user
    const activeColor = Color.fromARGB(255, 15, 245, 191);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 32; // -32 for margin
        // Selected item gets 40% width, unselected get 30% each (total 100%)
        // 40% is > 1/3 (33.3%)
        final double selectedWidth = totalWidth * 0.4;
        final double unselectedWidth = totalWidth * 0.3;

        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 34),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.home,
                        label: '主页',
                        isSelected: currentIndex == 0,
                        width: currentIndex == 0
                            ? selectedWidth
                            : unselectedWidth,
                        activeColor: activeColor,
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.chat_bubble,
                        label: '消息',
                        isSelected: currentIndex == 1,
                        width: currentIndex == 1
                            ? selectedWidth
                            : unselectedWidth,
                        activeColor: activeColor,
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.person,
                        label: '我的',
                        isSelected: currentIndex == 2,
                        width: currentIndex == 2
                            ? selectedWidth
                            : unselectedWidth,
                        activeColor: activeColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required double width,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        width: width,
        height: 64, // Slightly smaller than container height (80)
        decoration: BoxDecoration(
          // Bubble background color
          // Using a subtle grey for the selected background to let the icon pop,
          // matching the style of the provided images (grey bubble).
          color: isSelected ? Colors.grey.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? activeColor : Colors.grey[600],
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Optional: Show label for unselected?
            // The "plump" look usually has label only on selected or all?
            // The images show labels on ALL items but the selected one is emphasized.
            // Wait, looking closer at image 2: All items have labels ("主页", "广播", "资料库").
            if (!isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
