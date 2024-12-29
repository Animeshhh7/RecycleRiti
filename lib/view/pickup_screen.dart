import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recycle_riti/controller/bottom_nav_controller.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';
import 'package:recycle_riti/widgets/my_requests_tab.dart';
import 'package:recycle_riti/widgets/schedule_pickup_tab.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key});

  @override
  _PickupScreenState createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _currentTabTitle = "Schedule Pickup";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final int initialTabIndex = args?['initialTabIndex'] ?? 0;
      _tabController.animateTo(initialTabIndex);
      setState(() {
        _currentTabTitle = initialTabIndex == 0 ? "Schedule Pickup" : "My Requests";
      });

      NotificationScreen.initNotifications(
        context,
        onNotificationReceived: () {
          setState(() {});
          print('PickupScreen: Notification received, refreshing UI');
        },
      );
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabTitle = _tabController.index == 0 ? "Schedule Pickup" : "My Requests";
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    NotificationScreen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _currentTabTitle,
        isAgentScreen: false,
        showNotifications: true,
        onNotificationStateChanged: () {
          setState(() {});
          print('PickupScreen: Notification state changed, refreshing UI');
        },
        onBackPressed: () {
          // Navigate to HomeScreen tab (index 0)
          Provider.of<BottomNavController>(context, listen: false).changeIndex(0);
          print('PickupScreen: Back button pressed, navigated to HomeScreen');
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.secondaryTextColor,
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Schedule Pickup'),
                  Tab(text: 'My Requests'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  SchedulePickupTab(),
                  MyRequestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}// 22701
