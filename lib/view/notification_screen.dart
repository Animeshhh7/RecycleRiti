import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/main.dart' show scaffoldMessengerKey;
import 'package:recycle_riti/providers/notification_count_provider.dart';
import 'package:recycle_riti/routes/routes.dart';
import 'package:recycle_riti/services/notification_service.dart';
import 'package:recycle_riti/utils/notification_manager.dart';
import 'package:recycle_riti/utils/theme.dart';

class NotificationScreen {
  static final List<Map<String, dynamic>> _notifications = [];
  static Timer? _notificationTimer;
  static String? _userRole;
  static String? _currentAgentId;
  static VoidCallback? _onNotificationReceived;
  static VoidCallback? _notificationCallback;
  static DateTime? _lastSnackBarTime;
  static const Duration _snackBarDebounce = Duration(seconds: 5);

  static void setNotificationCallback(VoidCallback? callback) {
    _notificationCallback = callback;
  }

  static Future<void> initNotifications(BuildContext context, {VoidCallback? onNotificationReceived}) async {
    if (_notificationTimer != null) return;

    _onNotificationReceived = onNotificationReceived;

    await _fetchUserRole();

    NotificationService.setupFirebaseMessaging((id) async {
      print('Received FCM notification with ID: $id');
      try {
        await _fetchNotifications(context);
        if (context.mounted) {
          Provider.of<NotificationCountProvider>(context, listen: false).updateNotificationCount();
        }
        if (_onNotificationReceived != null) {
          _onNotificationReceived!();
        }
        if (_notificationCallback != null) {
          _notificationCallback!();
        }
        _showSnackBar(id);
      } catch (e) {
        print('Error handling FCM notification: $e');
      }
    });

    try {
      await _fetchNotifications(context);
      if (context.mounted) {
        Provider.of<NotificationCountProvider>(context, listen: false).updateNotificationCount();
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }

    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        await _fetchNotifications(context);
        if (context.mounted) {
          Provider.of<NotificationCountProvider>(context, listen: false).updateNotificationCount();
        }
      } catch (e) {
        print('Error in periodic notification fetch: $e');
      }
    });
  }

  static Future<void> _fetchUserRole() async {
    try {
      final response = await AuthService.getUserProfile();
      if (response['success']) {
        _userRole = response['user']['role']?.toString().toLowerCase();
        _currentAgentId = response['user']['id']?.toString();
        print('User role fetched: $_userRole, Agent ID: $_currentAgentId');
      } else {
        _userRole = 'user';
        _currentAgentId = null;
        print('Failed to fetch user role, defaulting to user');
      }
    } catch (e) {
      print('Failed to fetch user role: $e');
      _userRole = 'user';
      _currentAgentId = null;
    }
  }

  static Future<void> _fetchNotifications(BuildContext context) async {
    try {
      final latestNotifications = await NotificationService.fetchNotifications();
      print('Fetched ${latestNotifications.length} notifications');

      List<String> deletedIds = await NotificationManager.getDeletedNotifications();
      print('Deleted IDs: $deletedIds');

      _notifications.clear();
      for (var notification in latestNotifications) {
        String notificationId = notification['id'].toString();
        if (!deletedIds.contains(notificationId)) {
          _notifications.add({
            'notificationId': notificationId,
            'notificationMessage': notification['message'],
            'notificationType': notification['type'],
            'isRead': notification['isRead'] ?? false,
            'data': notification['data'] ?? {},
            'createdAt': notification['createdAt'],
          });
        }
      }

      _notifications.sort((a, b) => DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
      print('Notifications: ${_notifications.map((notification) => notification['notificationId']).toList()}');

      if (_notifications.isEmpty && latestNotifications.isNotEmpty && context.mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('No new notifications', style: AppTheme.bodyTextStyle.copyWith(color: Colors.white)),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Failed to fetch notifications: $e');
      if (context.mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Failed to load notifications: $e', style: AppTheme.bodyTextStyle.copyWith(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static void _showSnackBar(String id) {
    final now = DateTime.now();
    if (_lastSnackBarTime != null && now.difference(_lastSnackBarTime!) < _snackBarDebounce) {
      print('Debouncing SnackBar for ID $id');
      return;
    }

    Map<String, dynamic>? notification = _notifications.firstWhere(
      (notification) => notification['notificationId'] == id,
      orElse: () => <String, dynamic>{},
    );

    if (notification.isNotEmpty) {
      _lastSnackBarTime = now;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            notification['notificationMessage'] ?? 'Notification received',
            style: AppTheme.bodyTextStyle.copyWith(color: Colors.white, fontSize: 16),
          ),
          backgroundColor: notification['notificationType'] == 'pickup_cancelled' ||
                  notification['notificationType'] == 'event_cancellation' ||
                  notification['notificationType'] == 'pickup_deleted' ||
                  notification['notificationType'] == 'blog_rejected'
              ? Colors.redAccent
              : AppTheme.primaryColor,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              BuildContext? context = scaffoldMessengerKey.currentContext;
              if (context != null) {
                _handleNotificationTap(context, notification);
              }
            },
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  static Future<void> _handleNotificationTap(BuildContext context, Map<String, dynamic> notification) async {
    switch (notification['notificationType']) {
      case 'new_event':
      case 'event_cancellation':
        Navigator.pushNamed(context, AppRoutes.eventParticipation);
        break;
      case 'blog_approved':
      case 'blog_rejected':
        Navigator.pushNamed(context, AppRoutes.recyclingTips);
        print('Navigated to RecyclingTipsScreen for blog notification ID ${notification['data']['blogId']}');
        break;
      case 'pickup_request':
      case 'pickup_assigned':
        if (_userRole == 'agent') {
          Navigator.pushNamed(
            context,
            AppRoutes.trackRequestAgent,
            arguments: {'requestId': notification['data']['pickupId'].toString()},
          );
        }
        break;
      case 'pickup_completed':
      case 'pickup_cancelled':
      case 'pickup_deleted':
        Navigator.pushNamed(
          context,
          _userRole == 'agent' ? AppRoutes.trackRequestAgent : AppRoutes.trackRequestUser,
          arguments: {'requestId': notification['data']['pickupId'].toString()},
        );
        break;
      default:
        print('Unknown notification type: ${notification['notificationType']}');
    }
  }

  static void addEventNotification(String eventId, String message) {
    final notification = {
      'notificationId': eventId,
      'notificationMessage': message,
      'notificationType': 'new_event',
      'isRead': false,
      'data': {'eventId': eventId},
      'createdAt': DateTime.now().toIso8601String(),
    };
    if (!_notifications.any((notification) => notification['notificationId'] == eventId)) {
      _notifications.add(notification);
      print('Added event notification: $eventId');
    }
    if (_onNotificationReceived != null) {
      _onNotificationReceived!();
    }
    if (_notificationCallback != null) {
      _notificationCallback!();
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    try {
      await NotificationService.markNotificationAsRead(notificationId);
      var notification = _notifications.firstWhere(
        (notification) => notification['notificationId'] == notificationId,
        orElse: () => <String, dynamic>{},
      );
      if (notification.isNotEmpty) {
        notification['isRead'] = true;
        print('Marked notification $notificationId as read');
      }
      if (_onNotificationReceived != null) {
        _onNotificationReceived!();
      }
      if (_notificationCallback != null) {
        _notificationCallback!();
      }
    } catch (e) {
      print('Error marking $notificationId as read: $e');
    }
  }

  static Future<void> markAllAsRead() async {
    try {
      List<String> unreadIds = _notifications
          .where((notification) => !(notification['isRead'] ?? false))
          .map((notification) => notification['notificationId'] as String)
          .toList();
      if (unreadIds.isNotEmpty) {
        await NotificationService.markNotificationsAsRead(unreadIds);
        for (var notification in _notifications) {
          notification['isRead'] = true;
        }
        print('Marked all notifications as read: $unreadIds');
      }
      if (_onNotificationReceived != null) {
        _onNotificationReceived!();
      }
      if (_notificationCallback != null) {
        _notificationCallback!();
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  static Future<void> clearAllNotifications() async {
    try {
      List<String> notificationIds = _notifications.map((notification) => notification['notificationId'] as String).toList();
      if (notificationIds.isNotEmpty) {
        await NotificationManager.deleteAllNotifications(notificationIds);
        _notifications.clear();
        print('Cleared all notifications');
        if (scaffoldMessengerKey.currentContext != null) {
          Provider.of<NotificationCountProvider>(scaffoldMessengerKey.currentContext!, listen: false).resetCount();
        }
      }
      if (_onNotificationReceived != null) {
        _onNotificationReceived!();
      }
      if (_notificationCallback != null) {
        _notificationCallback!();
      }
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  static Future<void> showNotifications(BuildContext context, {required bool isAgent}) async {
    List<Map<String, dynamic>> notifications = List.from(_notifications);
    List<String> readIds = await NotificationManager.getReadNotifications();
    List<String> deletedIds = await NotificationManager.getDeletedNotifications();

    notifications.removeWhere((notification) => deletedIds.contains(notification['notificationId']));
    for (var notification in notifications) {
      notification['isRead'] = readIds.contains(notification['notificationId']) || notification['isRead'];
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppTheme.cardColor,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Notifications',
                            style: AppTheme.sectionTitleStyle.copyWith(
                              color: AppTheme.primaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.primaryColor, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: AppTheme.secondaryTextColor, thickness: 0.5, height: 10),
                      if (notifications.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await markAllAsRead();
                                setModalState(() {});
                              },
                              icon: const Icon(Icons.mark_email_read, color: AppTheme.primaryColor, size: 20),
                              label: Text(
                                'Mark All as Read',
                                style: AppTheme.bodyTextStyle.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                await clearAllNotifications();
                                setModalState(() {});
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              label: Text(
                                'Clear All',
                                style: AppTheme.bodyTextStyle.copyWith(
                                  color: Colors.redAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off,
                                size: 60,
                                color: AppTheme.secondaryTextColor.withOpacity(0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No notifications',
                                style: AppTheme.bodyTextStyle.copyWith(
                                  color: AppTheme.secondaryTextColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            bool isRead = notification['isRead'] ?? false;
                            bool isEvent = notification['notificationType'] == 'new_event';
                            bool isEventCancel = notification['notificationType'] == 'event_cancellation';
                            bool isPickupDone = notification['notificationType'] == 'pickup_completed';
                            bool isPickupCancel = notification['notificationType'] == 'pickup_cancelled';
                            bool isPickupDeleted = notification['notificationType'] == 'pickup_deleted';
                            bool isPickupRequest = notification['notificationType'] == 'pickup_request';
                            bool isPickupAssigned = notification['notificationType'] == 'pickup_assigned';
                            bool isBlogApproved = notification['notificationType'] == 'blog_approved';
                            bool isBlogRejected = notification['notificationType'] == 'blog_rejected';

                            return Card(
                              elevation: isRead ? 2 : 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isRead ? AppTheme.secondaryTextColor.withOpacity(0.2) : AppTheme.primaryColor,
                                  width: isRead ? 1 : 1.5,
                                ),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              color: isRead ? AppTheme.cardColor : Colors.white,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isRead ? AppTheme.cardColor : AppTheme.primaryColor.withOpacity(0.03),
                                  boxShadow: isRead
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withOpacity(0.15),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  leading: CircleAvatar(
                                    backgroundColor: isRead
                                        ? AppTheme.secondaryTextColor.withOpacity(0.2)
                                        : AppTheme.primaryColor.withOpacity(0.2),
                                    child: Icon(
                                      isEvent || isEventCancel
                                          ? Icons.event
                                          : isBlogApproved || isBlogRejected
                                              ? Icons.article
                                              : Icons.local_shipping,
                                      color: isRead ? AppTheme.secondaryTextColor : AppTheme.primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    notification['notificationMessage'] ?? 'Notification #${notification['notificationId']}',
                                    style: AppTheme.bodyTextStyle.copyWith(
                                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                      color: isRead ? AppTheme.textColor : AppTheme.primaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    DateTime.parse(notification['createdAt']).toLocal().toString().split('.')[0],
                                    style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () async {
                                      await NotificationManager.deleteNotification(notification['notificationId']);
                                      await _fetchNotifications(context);
                                      setModalState(() {});
                                    },
                                  ),
                                  onTap: () async {
                                    await markAsRead(notification['notificationId']);
                                    setModalState(() {});
                                    Navigator.pop(context);
                                    await _handleNotificationTap(context, notification);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Future<int> getNotificationCount() async {
    List<String> readIds = await NotificationManager.getReadNotifications();
    int count = _notifications.where((notification) => !readIds.contains(notification['notificationId']) && !(notification['isRead'] ?? false)).length;
    print('Notification count: $count');
    return count;
  }

  static void dispose() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _userRole = null;
    _currentAgentId = null;
    _onNotificationReceived = null;
    _notificationCallback = null;
    _lastSnackBarTime = null;
    print('Notification timer disposed');
  }
}// 17161
// 23846
// 4800
// 25290
