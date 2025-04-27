// lib/view/error_screen.dart
import 'package:flutter/material.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';

class ErrorScreen extends StatelessWidget {
  final String message;

  const ErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // Note: Ensure NotificationScreen.initNotifications(context) has been called
    // in a parent screen (e.g., HomeScreen or MainScreen) to enable notifications.
    // If this screen can be accessed directly without prior initialization,
    // consider converting to a StatefulWidget to call initNotifications in initState.

    return Scaffold(
      appBar: const CustomAppBar(
        title: "Error",
      ),
      body: Container(
        color: AppTheme.backgroundColor, // Use simple background color
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 50,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.main,
                    (Route<dynamic> route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                    (states) {
                      if (states.contains(WidgetState.pressed)) {
                        return AppTheme.accentColor;
                      }
                      return Colors.transparent;
                    },
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor, // Use solid color
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Text(
                      'Go to Home',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}