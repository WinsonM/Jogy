import 'package:flutter/material.dart';

class LocationButton extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final bool isCompassMode;

  const LocationButton({
    super.key,
    required this.onTap,
    this.onDoubleTap,
    this.isCompassMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isCompassMode
                ? const Color(0xFF3FAAF0)
                : Colors.white.withAlpha(240),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isCompassMode ? Icons.explore : Icons.my_location,
            color: isCompassMode ? Colors.white : Colors.grey[700],
            size: 24,
          ),
        ),
      ),
    );
  }
}
