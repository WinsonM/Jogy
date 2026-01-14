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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 90,
          color: Colors.white.withOpacity(0.85),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIcon(0, Icons.home_outlined, Icons.home_filled),
              _buildIcon(1, Icons.chat_bubble_outline, Icons.chat_bubble),
              _buildIcon(2, Icons.person_outline, Icons.person),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(int index, IconData outline, IconData filled) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          isSelected ? filled : outline,
          size: 28,
          color: Colors.black,
        ),
      ),
    );
  }
}
