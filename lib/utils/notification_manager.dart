import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/main.dart' show scaffoldMessengerKey;
import 'package:recycle_riti/providers/notification_count_provider.dart';
import 'package:recycle_riti/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationManager {
  static const String _readNotificationsKey = 'read_notifications';
  static const String _deletedNotificationsKey = 'deleted_notifications';
  static const String baseUrl = 'http://192.168.1.5:5000/api'; 

  static Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) {
      print('NotificationManager - Warning: Attempted to mark an empty notification ID as read');
      return;
    }
    try {
      // Mark as read in the backend
      await NotificationService.markNotificationAsRead(notificationId);

      // Update local storage
      final prefs = await SharedPreferences.getInstance();
      List<String> readIds = prefs.getStringList(_readNotificationsKey) ?? [];
      if (!readIds.contains(notificationId)) {
        readIds.add(notificationId);
        await prefs.setStringList(_readNotificationsKey, readIds);
        print('NotificationManager - Marked notification $notificationId as read locally');

        // Update the notification count
        BuildContext? context = scaffoldMessengerKey.currentContext;
        if (context != null) {
          Provider.of<NotificationCountProvider>(context, listen: false).updateNotificationCount();
        }
      }
    } catch (e) {
      print('NotificationManager - Error marking notification $notificationId as read: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  static Future<void> markAllAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) {
      print('NotificationManager - Warning: Attempted to mark an empty list of notifications as read');
      return;
    }
    try {
      // Mark all as read in the backend
      await NotificationService.markNotificationsAsRead(notificationIds);

      // Update local storage
      final prefs = await SharedPreferences.getInstance();
      List<String> readIds = prefs.getStringList(_readNotificationsKey) ?? [];
      readIds.addAll(notificationIds.where((id) => id.isNotEmpty && !readIds.contains(id)));
      await prefs.setStringList(_readNotificationsKey, readIds);
      print('NotificationManager - Marked all notifications as read locally: $notificationIds');

      // Update the notification count
      BuildContext? context = scaffoldMessengerKey.currentContext;
      if (context != null) {
        Provider.of<NotificationCountProvider>(context, listen: false).updateNotificationCount();
      }
    } catch (e) {
      print('NotificationManager - Error marking all notifications as read: $e');
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  static Future<void> deleteNotification(String notificationId) async {
    if (notificationId.isEmpty) {
      print('NotificationManager - Warning: Attempted to delete an empty notification ID');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> deletedIds = prefs.getStringList(_deletedNotificationsKey) ?? [];
      if (!deletedIds.contains(notificationId)) {
        deletedIds.add(notificationId);
        await prefs.setStringList(_deletedNotificationsKey, deletedIds);
        print('NotificationManager - Deleted notification $notificationId locally');

        // Update the notification count
        BuildContext? context = scaffoldMessengerKey.currentContext;
        if (context != null) {
          Provider.of<NotificationCountProvider>(context, listen: false).updateNotificationCount();
        }
      }
    } catch (e) {
      print('NotificationManager - Error deleting notification $notificationId: $e');
      throw Exception('Failed to delete notification: $e');
    }
  }

  static Future<void> deleteAllNotifications(List<String> notificationIds) async {
    if (notificationIds.isEmpty) {
      print('NotificationManager - Warning: Attempted to delete an empty list of notifications');
      return;
    }
    try {
      // Delete all notifications from the backend
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/clear'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to clear notifications: ${response.statusCode} - ${response.body}');
      }
      print('NotificationManager - Successfully cleared notifications from backend');

      // Update local storage
      final prefs = await SharedPreferences.getInstance();
      List<String> deletedIds = prefs.getStringList(_deletedNotificationsKey) ?? [];
      deletedIds.addAll(notificationIds.where((id) => id.isNotEmpty && !deletedIds.contains(id)));
      await prefs.setStringList(_deletedNotificationsKey, deletedIds);
      print('NotificationManager - Deleted all notifications locally: $notificationIds');

      // Update the notification count
      BuildContext? context = scaffoldMessengerKey.currentContext;
      if (context != null) {
        Provider.of<NotificationCountProvider>(context, listen: false).updateNotificationCount();
      }
    } catch (e) {
      print('NotificationManager - Error deleting all notifications: $e');
      throw Exception('Failed to delete all notifications: $e');
    }
  }

  static Future<List<String>> getReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList(_readNotificationsKey) ?? [];
      print('NotificationManager - Retrieved read notifications: $readIds');
      return readIds;
    } catch (e) {
      print('NotificationManager - Error retrieving read notifications: $e');
      return [];
    }
  }

  static Future<List<String>> getDeletedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletedIds = prefs.getStringList(_deletedNotificationsKey) ?? [];
      print('NotificationManager - Retrieved deleted notifications: $deletedIds');
      return deletedIds;
    } catch (e) {
      print('NotificationManager - Error retrieving deleted notifications: $e');
      return [];
    }
  }

  static Future<bool> isNotificationRead(String notificationId) async {
    if (notificationId.isEmpty) {
      print('NotificationManager - Warning: Checked read status for an empty notification ID');
      return false;
    }
    try {
      final readIds = await getReadNotifications();
      final isRead = readIds.contains(notificationId);
      print('NotificationManager - Notification $notificationId isRead: $isRead');
      return isRead;
    } catch (e) {
      print('NotificationManager - Error checking if notification $notificationId is read: $e');
      return false;
    }
  }

  static Future<bool> isNotificationDeleted(String notificationId) async {
    if (notificationId.isEmpty) {
      print('NotificationManager - Warning: Checked deleted status for an empty notification ID');
      return false;
    }
    try {
      final deletedIds = await getDeletedNotifications();
      final isDeleted = deletedIds.contains(notificationId);
      print('NotificationManager - Notification $notificationId isDeleted: $isDeleted');
      return isDeleted;
    } catch (e) {
      print('NotificationManager - Error checking if notification $notificationId is deleted: $e');
      return false;
    }
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_readNotificationsKey);
      await prefs.remove(_deletedNotificationsKey);
      print('NotificationManager - Cleared all notification data locally');

      // Update the notification count
      BuildContext? context = scaffoldMessengerKey.currentContext;
      if (context != null) {
        Provider.of<NotificationCountProvider>(context, listen: false).updateNotificationCount();
      }
    } catch (e) {
      print('NotificationManager - Error clearing all notification data: $e');
      throw Exception('Failed to clear all notification data: $e');
    }
  }
}// 2559
// 25380
// 29201
