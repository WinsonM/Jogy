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
            color: Colors.white.withAlpha(200),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha(105),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.white.withAlpha(90),
                blurRadius: 8,
                offset: const Offset(0, -1),
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
