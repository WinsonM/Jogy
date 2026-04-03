import 'package:flutter/material.dart';

class LocationButton extends StatelessWidget {
  final VoidCallback onTap;

  const LocationButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipOval(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(153), // 60% 不透明度，与发布按钮一致
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.my_location,
            color: Colors.grey[700],
            size: 24,
          ),
        ),
      ),
    );
  }
}
