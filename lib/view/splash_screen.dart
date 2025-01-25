// lib/view/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:recycle_riti/utils/theme.dart';

class SplashScreen extends StatefulWidget {
  final Future<String> Function() onInitializationComplete;

  const SplashScreen({super.key, required this.onInitializationComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final initialRoute = await widget.onInitializationComplete();
    if (mounted) {
      Navigator.pushReplacementNamed(context, initialRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Background gradient consistent with app theme
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundColor,
              AppTheme.primaryColor.withOpacity(0.1),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.recycling,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                'Recycle Riti',
                style: AppTheme.sectionTitleStyle.copyWith(
                  fontSize: 28,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}// 28510
// 4667
// 12438
// 13055
