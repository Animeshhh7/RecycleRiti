import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recycle_riti/providers/notification_count_provider.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leadingWidget;
  final bool isAgentScreen;
  final VoidCallback? onMenuPressed;
  final bool showNotifications;
  final VoidCallback? onNotificationStateChanged;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.leadingWidget,
    this.isAgentScreen = false,
    this.onMenuPressed,
    this.showNotifications = false,
    this.onNotificationStateChanged,
    this.onBackPressed,
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
                  onPressed: onBackPressed ?? () => Navigator.pop(context),
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
        if (showNotifications)
          Consumer<NotificationCountProvider>(
            builder: (context, provider, child) {
              print('CustomAppBar - Notification count: ${provider.notificationCount}');
              return badges.Badge(
                badgeContent: Text(
                  provider.notificationCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                showBadge: provider.notificationCount > 0,
                badgeStyle: const badges.BadgeStyle(badgeColor: Colors.redAccent),
                position: badges.BadgePosition.topEnd(top: 0, end: 3),
                child: IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () async {
                    print('CustomAppBar - Opening notifications modal');
                    try {
                      await NotificationScreen.showNotifications(
                        context,
                        isAgent: isAgentScreen,
                      );
                      if (onNotificationStateChanged != null) {
                        onNotificationStateChanged!();
                      }
                      if (context.mounted) {
                        Provider.of<NotificationCountProvider>(context, listen: false).updateNotificationCount();
                      }
                    } catch (e) {
                      print('CustomAppBar - Error showing notifications: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to load notifications: $e', style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.redAccent,
                            duration: const Duration(seconds: 5),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
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
}// 21228
