// lib/widgets/timeline_tile.dart
import 'package:flutter/material.dart';
import 'package:recycle_riti/utils/theme.dart';

// A reusable widget for displaying a timeline tile in tracking screens
class TimelineTile extends StatelessWidget {
  final String status;
  final String title;
  final String date;
  final bool isFirst;
  final bool isLast;

  const TimelineTile({
    super.key,
    required this.status,
    required this.title,
    required this.date,
    this.isFirst = false,
    this.isLast = false,
  });

  Color _getStatusColor() {
    if (status == 'completed') return AppTheme.primaryColor;
    if (status == 'cancelled') return Colors.redAccent;
    return AppTheme.secondaryTextColor;
  }

  IconData _getStatusIcon() {
    if (status == 'completed') return Icons.check_circle;
    if (status == 'cancelled') return Icons.cancel;
    return Icons.hourglass_empty;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (!isFirst) const SizedBox(height: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statusColor,
                    statusColor.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(statusIcon, color: Colors.white, size: 24),
            ),
            if (!isLast)
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      statusColor,
                      statusColor.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyTextStyle.copyWith(
                    color: status == 'completed' || status == 'cancelled'
                        ? AppTheme.textColor
                        : AppTheme.secondaryTextColor,
                    fontWeight: status == 'completed' ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: AppTheme.bodyTextStyle.copyWith(
                    color: AppTheme.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}// 13584
// 3424
// 29866
// 2956
