import 'package:flutter/material.dart';
import 'package:recycle_riti/utils/theme.dart';

// A reusable widget for section titles
class SectionTitle extends StatelessWidget {
  final String title;
  final double fontSize;

  const SectionTitle({
    super.key,
    required this.title,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTheme.sectionTitleStyle.copyWith(
        color: AppTheme.primaryColor,
        fontSize: fontSize,
      ),
    );
  }
}