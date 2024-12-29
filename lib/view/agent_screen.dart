import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/agent_dashboard.dart';
import 'package:recycle_riti/widgets/agent_drawer.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _agentDetails;
  bool _isLoading = true;
  String? _profileImageUrl;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchAgentDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationScreen.initNotifications(
        context,
        onNotificationReceived: () {
          setState(() {});
          print('AgentScreen: Notification received, refreshing UI');
        },
      );
    });
  }

  @override
  void dispose() {
    NotificationScreen.dispose(); // Ensure static method call
    super.dispose();
  }

  Future<void> _fetchAgentDetails() async {
    setState(() {
      _isLoading = true;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () async {
        final token = await AuthService.getAccessToken();
        if (token == null || token.isEmpty) {
          throw Exception('No access token found. Please log in.');
        }
        return await AuthService.getUserProfile();
      },
      defaultErrorMessage: 'Failed to load agent details',
      retryCallback: _fetchAgentDetails,
      onSuccess: (data) async {
        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Failed to fetch agent details');
        }
        setState(() {
          _agentDetails = data['user'];
          String? profileImagePath = data['user']['profileImage'];
          if (profileImagePath != null) {
            profileImagePath = profileImagePath.replaceFirst('/uploads/', '');
            _profileImageUrl =
                '${AuthService.baseUrl.replaceAll('/api', '')}/uploads/$profileImagePath?t=${DateTime.now().millisecondsSinceEpoch}';
          } else {
            _profileImageUrl = null;
          }
        });

        try {
          String agentId = data['user']['id'].toString();
          FirebaseMessaging messaging = FirebaseMessaging.instance;
          await messaging.subscribeToTopic('agent_$agentId');
          await messaging.subscribeToTopic('agents');
          print('Subscribed to agent_$agentId and agents');
        } catch (e) {
          print('Failed to subscribe to FCM topics: $e');
          ExceptionHandling.showSnackBar(context, 'Failed to set up notifications: $e');
        }
      },
    );

    setState(() {
      _isLoading = false;
    });
  }

  void _logout() async {
    try {
      await _authService.logout();
      NotificationScreen.dispose(); // Ensure static method call
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('Logout error: $e');
      ExceptionHandling.showSnackBar(context, 'Failed to logout: $e');
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(
        title: "Agent Dashboard",
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        isAgentScreen: true,
        showNotifications: true,
        onNotificationStateChanged: () {
          setState(() {});
          print('AgentScreen: Notification state changed, refreshing UI');
        },
      ),
      drawer: _agentDetails == null
          ? null
          : AgentDrawer(
              onLogout: _logout,
              agentUsername: _agentDetails?['username'],
              agentDetails: _agentDetails,
            ),
      drawerEnableOpenDragGesture: false,
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
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : AgentDashboard(
                agentUsername: _agentDetails?['username'],
                currentAgentId: _agentDetails?['id']?.toString(),
                agentDetails: _agentDetails,
              ),
      ),
    );
  }
}// 17595
