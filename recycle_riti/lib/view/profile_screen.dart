// lib/view/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/controller/bottom_nav_controller.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/notification_manager.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';
import 'package:recycle_riti/widgets/custom_button.dart';
import 'package:recycle_riti/widgets/profile_header.dart';
import 'package:recycle_riti/widgets/profile_options.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _profileImageUrl;
  String? _userRole;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _checkTokenAndLoadDetails();
    // Initialize notifications with a callback to refresh the UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationScreen.initNotifications(
        context,
        onNotificationReceived: () {
          setState(() {}); // Refresh the UI when a notification is received
        },
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    NotificationScreen.dispose();
    super.dispose();
  }

  Future<void> _checkTokenAndLoadDetails() async {
    await ExceptionHandling.handleApiCall<void>(
      context,
      () async {
        final token = await AuthService.getAccessToken();
        if (token == null || token.isEmpty) {
          throw Exception('No access token found. Please log in.');
        }
        await _loadUserDetails();
      },
      defaultErrorMessage: 'Error verifying session',
      onSuccess: (_) {},
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _loadUserDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.getUserProfile(),
      defaultErrorMessage: 'Failed to fetch user profile',
      onSuccess: (data) {
        if (mounted) {
          setState(() {
            _userName = data['user']['username'] ?? 'User Name';
            _userEmail = data['user']['email'] ?? 'useremail@example.com';
            _userPhone = data['user']['phone'] ?? 'Not provided';
            _userRole = data['user']['role']?.toString().toLowerCase();
            String? profileImagePath = data['user']['profileImage'];
            if (profileImagePath != null) {
              profileImagePath = profileImagePath.replaceFirst('/uploads/', '');
              _profileImageUrl =
                  '${AuthService.baseUrl.replaceAll('/api', '')}/uploads/$profileImagePath?t=${DateTime.now().millisecondsSinceEpoch}';
            } else {
              _profileImageUrl = null;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
            _userName = 'User Name';
            _userEmail = 'useremail@example.com';
            _userPhone = 'Not provided';
            _userRole = 'user';
            _profileImageUrl = null;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text('Logout', style: AppTheme.sectionTitleStyle.copyWith(fontSize: 20)),
        content: Text('Are you sure you want to log out?', style: AppTheme.bodyTextStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: AppTheme.bodyTextStyle.copyWith(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ExceptionHandling.handleVoidApiCall(
        context,
        () async {
          await AuthService.logout();
          await NotificationManager.clearAll();
          NotificationScreen.dispose();
        },
        defaultErrorMessage: 'Logout failed',
        onSuccess: () {
          Provider.of<BottomNavController>(context, listen: false).resetIndex();
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (Route<dynamic> route) => false);
          ExceptionHandling.showSnackBar(context, 'Logged out successfully');
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Profile",
        isAgentScreen: _userRole == 'agent',
        showNotifications: true,
        onNotificationStateChanged: () {
          setState(() {}); // Already set up to refresh the badge count
        },
      ),
      body: Container(
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
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3))
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 50, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'An error occurred',
                          style: AppTheme.bodyTextStyle.copyWith(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        CustomButton(
                          onPressed: _checkTokenAndLoadDetails,
                          color: AppTheme.primaryColor,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Retry",
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: RefreshIndicator(
                      onRefresh: _loadUserDetails,
                      color: AppTheme.primaryColor,
                      backgroundColor: AppTheme.cardColor,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ProfileHeader(
                              userName: _userName ?? 'User Name',
                              userEmail: _userEmail ?? 'useremail@example.com',
                              userPhone: _userPhone ?? 'Not provided',
                              profileImageUrl: _profileImageUrl,
                              onRefresh: _loadUserDetails,
                            ),
                            const SizedBox(height: 24),
                            ProfileOptions(
                              onLogout: _handleLogout,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}