// lib/view/placeholder_screen.dart
import 'package:flutter/material.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    // Note: Ensure NotificationScreen.initNotifications(context) has been called
    // in a parent screen (e.g., HomeScreen or MainScreen) to enable notifications.
    // If this screen can be accessed directly without prior initialization,
    // consider converting to a StatefulWidget to call initNotifications in initState.

    return Scaffold(
      appBar: CustomAppBar(
        title: title,
      ),
      body: Container(
        color: AppTheme.backgroundColor, // Use simple background color
        child: Center(
          child: Text(
            '$title\nUnder Development',
            style: AppTheme.sectionTitleStyle.copyWith(
              color: AppTheme.primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}// 10379
// 2736
// 23717
// 14646
