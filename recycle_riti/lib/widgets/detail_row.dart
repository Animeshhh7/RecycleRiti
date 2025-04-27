import 'package:flutter/material.dart';
import 'package:recycle_riti/utils/theme.dart';

// A reusable widget to display a key-value pair in a row
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double fontSize;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: AppTheme.bodyTextStyle.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyTextStyle.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}