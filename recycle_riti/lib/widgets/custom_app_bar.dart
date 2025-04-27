// lib/widgets/custom_app_bar.dart
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leadingWidget; // Custom leading widget (profile image, back button, or menu icon)
  final VoidCallback? onMenuPressed; // For menu icon in AgentScreen
  final bool isAgentScreen; // Flag to determine if this is AgentScreen
  final bool showNotifications; // Flag to determine if notifications should be shown
  final VoidCallback? onNotificationStateChanged; // Callback to notify parent of state changes

  const CustomAppBar({
    super.key,
    required this.title,
    this.leadingWidget,
    this.onMenuPressed,
    this.isAgentScreen = false,
    this.showNotifications = false,
    this.onNotificationStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.appBarColor,
      elevation: 2,
      leading: leadingWidget ??
          (isAgentScreen
              ? IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: onMenuPressed,
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )),
      title: Center(
        child: Text(
          title,
          style: AppTheme.sectionTitleStyle.copyWith(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
      actions: [
        if (showNotifications) // Conditionally show notification icon
          FutureBuilder<int>(
            future: NotificationScreen.getNotificationCount(),
            builder: (context, snapshot) {
              int notificationCount = snapshot.data ?? 0;
              return badges.Badge(
                badgeContent: Text(
                  notificationCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                showBadge: notificationCount > 0,
                badgeStyle: const badges.BadgeStyle(badgeColor: Colors.redAccent),
                position: badges.BadgePosition.topEnd(top: 0, end: 3),
                child: IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () async {
                    await NotificationScreen.showNotifications(
                      context,
                      isAgent: isAgentScreen,
                    );
                    // Notify parent to update state (e.g., refresh badge count)
                    if (onNotificationStateChanged != null) {
                      onNotificationStateChanged!();
                    }
                  },
                  tooltip: 'Notifications',
                ),
              );
            },
          ),
        const SizedBox(width: 16),
      ],
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}