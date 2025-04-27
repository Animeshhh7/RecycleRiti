import 'dart:async';

import 'package:flutter/material.dart';
import 'package:recycle_riti/api/rest_auth.dart';
// Import the global ScaffoldMessenger key from main.dart
import 'package:recycle_riti/main.dart' show scaffoldMessengerKey;
import 'package:recycle_riti/services/notification_service.dart';
import 'package:recycle_riti/utils/notification_manager.dart';
import 'package:recycle_riti/utils/theme.dart';

class NotificationScreen {
  static final List<Map<String, dynamic>> _newRequests = [];
  static final List<Map<String, dynamic>> _userNotifications = [];
  static Timer? _notificationTimer;
  static String? _userRole;
  static String? _currentAgentId;
  static VoidCallback? _onNotificationReceived; // Callback to refresh badge

  static Future<void> initNotifications(BuildContext context, {VoidCallback? onNotificationReceived}) async {
    if (_notificationTimer != null) return;

    _onNotificationReceived = onNotificationReceived; // Store callback for badge refresh

    await _fetchUserRole();

    // Set up Firebase Messaging to listen for instant notifications
    NotificationService.setupFirebaseMessaging((requestId) async {
      print('Received FCM notification for request ID: $requestId');
      // Fetch the latest requests to update the notification list
      if (_userRole == 'agent') {
        await _checkForNewRequests(context);
      } else if (_userRole == 'user') {
        await _checkForUserNotifications(context);
      }
      // Trigger badge refresh
      if (_onNotificationReceived != null) {
        _onNotificationReceived!();
      }
      // Show a SnackBar with the notification message
      _showCancellationSnackBar(requestId);
    });

    // Initial fetch
    if (_userRole == 'agent') {
      await _checkForNewRequests(context);
    } else if (_userRole == 'user') {
      await _checkForUserNotifications(context);
    }

    // Keep the periodic timer for fallback (e.g., if FCM fails)
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_userRole == 'agent') {
        _checkForNewRequests(context);
      } else if (_userRole == 'user') {
        _checkForUserNotifications(context);
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

  static void _showCancellationSnackBar(String requestId) {
    // Find the notification in the list
    Map<String, dynamic>? notification;
    if (_userRole == 'agent') {
      notification = _newRequests.firstWhere(
        (request) => request['notificationId'] == requestId,
        orElse: () => <String, dynamic>{},
      );
    } else {
      notification = _userNotifications.firstWhere(
        (request) => request['notificationId'] == requestId,
        orElse: () => <String, dynamic>{},
      );
    }

    if (notification.isNotEmpty && notification['notificationType'] == 'cancelled') {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            notification['notificationMessage'] ?? 'Notification received',
            style: AppTheme.bodyTextStyle.copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Navigate to the request details
              BuildContext? context = scaffoldMessengerKey.currentContext;
              if (context != null) {
                if (_userRole == 'agent') {
                  Navigator.pushNamed(
                    context,
                    '/track-request-agent',
                    arguments: {'requestId': requestId},
                  );
                } else {
                  Navigator.pushNamed(
                    context,
                    '/track-request-user',
                    arguments: {'requestId': requestId},
                  );
                }
              }
            },
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  static Future<void> _checkForNewRequests(BuildContext context) async {
    try {
      final response = await AuthService.getPickupRequests();
      if (response['success'] != true) {
        print('Failed to fetch pickup requests for agent: ${response['message']}');
        return;
      }

      List<dynamic> latestRequests = response['pickupRequests'] ?? [];
      print('Agent fetched ${latestRequests.length} requests');

      List<String> deletedIds = await NotificationManager.getDeletedNotifications();
      print('Deleted notification IDs: $deletedIds');

      List<Map<String, dynamic>> newPendingRequests = latestRequests
          .where((request) {
            bool isPending = request['status']?.toString().toLowerCase() == 'pending';
            bool isUnassigned = request['agent'] == null || (request['agent'] is Map && request['agent'].isEmpty);
            bool isNew = !_newRequests.any((existing) => existing['id'] == request['id']);
            bool notDeleted = !deletedIds.contains(request['id']?.toString());
            print('Request ${request['id']}: isPending=$isPending, isUnassigned=$isUnassigned, isNew=$isNew, notDeleted=$notDeleted, agent=${request['agent']}');
            return isPending && isUnassigned && isNew && notDeleted;
          })
          .cast<Map<String, dynamic>>()
          .toList();

      if (newPendingRequests.isNotEmpty) {
        print('Agent found ${newPendingRequests.length} new pending requests: ${newPendingRequests.map((r) => r['id']).toList()}');
        _newRequests.addAll(newPendingRequests);
        for (var request in newPendingRequests) {
          request['notificationMessage'] =
              "Hurry up! A user just initiated a new pickup request. Check it out!";
          request['notificationId'] = request['id'].toString();
          request['isRead'] = false;
          request['notificationType'] = 'pending';
          print('Added pending notification for request ${request['id']}');
        }
      }

      List<Map<String, dynamic>> cancelledRequests = latestRequests
          .where((request) {
            bool isCancelled = request['status']?.toString().toLowerCase() == 'cancelled';
            bool notDeleted = !deletedIds.contains(request['id']?.toString());
            var previousRequest = _newRequests.firstWhere(
              (existing) => existing['id'] == request['id'],
              orElse: () => <String, dynamic>{},
            );
            bool wasRelevant = previousRequest.isNotEmpty &&
                (previousRequest['notificationType'] == 'pending' ||
                    (previousRequest['notificationType'] == 'accepted' &&
                        request['agent'] != null &&
                        request['agent']['id']?.toString() == _currentAgentId));
            print('Request ${request['id']}: isCancelled=$isCancelled, wasRelevant=$wasRelevant, notDeleted=$notDeleted, agent=${request['agent']}');
            return isCancelled && wasRelevant && notDeleted;
          })
          .cast<Map<String, dynamic>>()
          .toList();

      if (cancelledRequests.isNotEmpty) {
        print('Agent found ${cancelledRequests.length} cancelled requests: ${cancelledRequests.map((r) => r['id']).toList()}');
        for (var request in cancelledRequests) {
          var existingNotification = _newRequests.firstWhere(
            (existing) => existing['id'] == request['id'],
            orElse: () => <String, dynamic>{},
          );
          if (existingNotification.isNotEmpty) {
            existingNotification['notificationMessage'] =
                "Sorry to inform you that the pickup has been cancelled! Apologies for the inconvenience.";
            existingNotification['notificationType'] = 'cancelled';
            existingNotification['isRead'] = false;
            print('Updated notification for cancelled request ${request['id']}');
          } else {
            request['notificationMessage'] =
                "Sorry to inform you that the pickup has been cancelled! Apologies for the inconvenience.";
            request['notificationId'] = request['id'].toString();
            request['isRead'] = false;
            request['notificationType'] = 'cancelled';
            _newRequests.add(request);
            print('Added new cancelled notification for request ${request['id']}');
          }
        }
      }

      _newRequests.removeWhere((request) =>
          !latestRequests.any((latest) => latest['id'] == request['id']));
      print('Current agent notifications: ${_newRequests.map((n) => n['notificationId']).toList()}');
    } catch (e) {
      print('NotificationScreen - Failed to check for new requests: $e');
    }
  }

  static Future<void> _checkForUserNotifications(BuildContext context) async {
    try {
      final response = await AuthService.getPickupRequests();
      if (response['success'] != true) {
        print('Failed to fetch pickup requests for user: ${response['message']}');
        return;
      }

      List<dynamic> latestRequests = response['pickupRequests'] ?? [];
      print('User fetched ${latestRequests.length} requests');

      List<String> deletedIds = await NotificationManager.getDeletedNotifications();
      print('Deleted notification IDs: $deletedIds');

      List<Map<String, dynamic>> newNotifications = latestRequests
          .where((request) {
            bool isRelevantStatus = (request['status']?.toString().toLowerCase() == 'accepted' ||
                request['status']?.toString().toLowerCase() == 'cancelled' ||
                request['status']?.toString().toLowerCase() == 'completed');
            bool isNew = !_userNotifications.any((existing) => existing['id'] == request['id']);
            bool notDeleted = !deletedIds.contains(request['id']?.toString());
            print('Request ${request['id']}: isRelevantStatus=$isRelevantStatus, isNew=$isNew, notDeleted=$notDeleted');
            return isRelevantStatus && isNew && notDeleted;
          })
          .cast<Map<String, dynamic>>()
          .toList();

      if (newNotifications.isNotEmpty) {
        print('User found ${newNotifications.length} new notifications: ${newNotifications.map((r) => r['id']).toList()}');
        _userNotifications.addAll(newNotifications);
        for (var request in newNotifications) {
          String status = request['status']?.toString().toLowerCase() ?? '';
          String agentName;
          if (status == 'cancelled' && (request['agent'] == null || (request['agent'] is Map && request['agent'].isEmpty))) {
            agentName = 'User';
          } else {
            agentName = request['agent']?['username']?.toString() ?? 'Unknown Agent';
          }
          switch (status) {
            case 'accepted':
              request['notificationMessage'] =
                  "Your pickup request has been accepted by an agent!\nAgent: $agentName";
              break;
            case 'cancelled':
              request['notificationMessage'] =
                  "Sorry your requested pickup has unfortunately been cancelled! Apologies for the inconvenience. You can always schedule your next pickup anytime!";
              break;
            case 'completed':
              request['notificationMessage'] =
                  "Your pickup request has been successfully completed!\nAgent: $agentName";
              break;
            default:
              request['notificationMessage'] = "Update on your pickup request: $status\nAgent: $agentName";
          }
          request['notificationId'] = request['id'].toString();
          request['isRead'] = false;
          print('Added user notification for request ${request['id']} with status $status, agent: $agentName');
        }
      }

      _userNotifications.removeWhere((request) =>
          !latestRequests.any((latest) => latest['id'] == request['id']));
      print('Current user notifications: ${_userNotifications.map((n) => n['notificationId']).toList()}');
    } catch (e) {
      print('NotificationScreen - Failed to check for user notifications: $e');
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    await NotificationManager.markAsRead(notificationId);
    if (_userRole == 'agent') {
      var notification = _newRequests.firstWhere(
        (request) => request['notificationId'] == notificationId,
        orElse: () => <String, dynamic>{},
      );
      if (notification.isNotEmpty) {
        notification['isRead'] = true;
        print('Marked agent notification $notificationId as read');
      }
    } else {
      var notification = _userNotifications.firstWhere(
        (request) => request['notificationId'] == notificationId,
        orElse: () => <String, dynamic>{},
      );
      if (notification.isNotEmpty) {
        notification['isRead'] = true;
        print('Marked user notification $notificationId as read');
      }
    }
    // Trigger badge refresh
    if (_onNotificationReceived != null) {
      _onNotificationReceived!();
    }
  }

  static Future<void> markAllAsRead() async {
    if (_userRole == 'agent') {
      List<String> notificationIds = _newRequests.map((request) => request['notificationId'] as String).toList();
      await NotificationManager.markAllAsRead(notificationIds);
      for (var request in _newRequests) {
        request['isRead'] = true;
      }
      print('Marked all agent notifications as read: $notificationIds');
    } else {
      List<String> notificationIds = _userNotifications.map((request) => request['notificationId'] as String).toList();
      await NotificationManager.markAllAsRead(notificationIds);
      for (var request in _userNotifications) {
        request['isRead'] = true;
      }
      print('Marked all user notifications as read: $notificationIds');
    }
    // Trigger badge refresh
    if (_onNotificationReceived != null) {
      _onNotificationReceived!();
    }
  }

  static Future<void> clearAllNotifications() async {
    if (_userRole == 'agent') {
      List<String> notificationIds = _newRequests.map((request) => request['notificationId'] as String).toList();
      await NotificationManager.deleteAllNotifications(notificationIds);
      _newRequests.clear();
      print('Cleared all agent notifications: $notificationIds');
    } else {
      List<String> notificationIds = _userNotifications.map((request) => request['notificationId'] as String).toList();
      await NotificationManager.deleteAllNotifications(notificationIds);
      _userNotifications.clear();
      print('Cleared all user notifications: $notificationIds');
    }
    // Trigger badge refresh
    if (_onNotificationReceived != null) {
      _onNotificationReceived!();
    }
  }

  static Future<void> showNotifications(BuildContext context, {required bool isAgent}) async {
    List<Map<String, dynamic>> notifications = isAgent ? _newRequests : _userNotifications;

    List<String> readIds = await NotificationManager.getReadNotifications();
    List<String> deletedIds = await NotificationManager.getDeletedNotifications();

    for (var notification in List<Map<String, dynamic>>.from(notifications)) {
      String notificationId = notification['notificationId'] as String;
      if (deletedIds.contains(notificationId)) {
        notifications.removeWhere((n) => n['notificationId'] == notificationId);
        print('Removed deleted notification $notificationId');
      } else {
        notification['isRead'] = readIds.contains(notificationId);
      }
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
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const Divider(
                        color: AppTheme.secondaryTextColor,
                        thickness: 0.5,
                        height: 10,
                      ),
                      if (notifications.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await markAllAsRead();
                                setModalState(() {});
                              },
                              icon: const Icon(
                                Icons.mark_email_read,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
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
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
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
                                'No new notifications available',
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
                            final request = notifications[index];
                            bool isRead = request['isRead'] ?? false;
                            return Card(
                              elevation: isRead ? 2 : 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isRead
                                      ? AppTheme.secondaryTextColor.withOpacity(0.2)
                                      : AppTheme.primaryColor,
                                  width: isRead ? 1 : 1.5,
                                ),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              color: isRead ? AppTheme.cardColor : Colors.white,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isRead
                                      ? AppTheme.cardColor
                                      : AppTheme.primaryColor.withOpacity(0.03),
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
                                      Icons.local_shipping,
                                      color: isRead ? AppTheme.secondaryTextColor : AppTheme.primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    request['notificationMessage'] ??
                                        'Request #${request['id']?.toString() ?? 'N/A'}',
                                    style: AppTheme.bodyTextStyle.copyWith(
                                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                      color: isRead ? AppTheme.textColor : AppTheme.primaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                  onTap: () async {
                                    await markAsRead(request['notificationId']);
                                    setModalState(() {});
                                    Navigator.pop(context);
                                    if (isAgent) {
                                      Navigator.pushNamed(
                                        context,
                                        '/track-request-agent',
                                        arguments: {'requestId': request['id']?.toString() ?? ''},
                                      );
                                    } else {
                                      Navigator.pushNamed(
                                        context,
                                        '/track-request-user',
                                        arguments: {'requestId': request['id']?.toString() ?? ''},
                                      );
                                    }
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
    if (_userRole == 'agent') {
      int count = _newRequests.where((request) => !readIds.contains(request['notificationId'])).length;
      print('Agent notification count: $count');
      return count;
    } else {
      int count = _userNotifications.where((request) => !readIds.contains(request['notificationId'])).length;
      print('User notification count: $count');
      return count;
    }
  }

  static void dispose() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _userRole = null;
    _currentAgentId = null;
    _onNotificationReceived = null;
    print('Notification timer disposed, notifications preserved');
  }
}