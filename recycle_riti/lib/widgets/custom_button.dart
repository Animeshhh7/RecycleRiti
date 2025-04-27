// lib/widgets/custom_button.dart
import 'package:flutter/material.dart';
import 'package:recycle_riti/utils/theme.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color? color;
  final bool isMini;
  final bool isOutlined;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.isMini = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: isOutlined ? (color ?? AppTheme.primaryColor) : Colors.white,
        backgroundColor: isOutlined ? Colors.white : (color ?? AppTheme.primaryColor),
        padding: isMini
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isOutlined
              ? BorderSide(color: color ?? AppTheme.primaryColor, width: 1.5)
              : BorderSide.none,
        ),
        elevation: 0, // Remove elevation to eliminate shadow
        shadowColor: Colors.transparent, // Ensure no shadow is applied
      ),
      child: child,
    );
  }
}