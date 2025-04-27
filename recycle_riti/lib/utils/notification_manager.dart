
// lib/utils/notification_manager.dart
import 'package:shared_preferences/shared_preferences.dart';

class NotificationManager {
  static const String _readNotificationsKey = 'read_notifications';
  static const String _deletedNotificationsKey = 'deleted_notifications';

  static Future<void> markAsRead(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> readIds = prefs.getStringList(_readNotificationsKey) ?? [];
    if (!readIds.contains(notificationId)) {
      readIds.add(notificationId);
      await prefs.setStringList(_readNotificationsKey, readIds);
    }
  }

  static Future<void> markAllAsRead(List<String> notificationIds) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> readIds = prefs.getStringList(_readNotificationsKey) ?? [];
    readIds.addAll(notificationIds.where((id) => !readIds.contains(id)));
    await prefs.setStringList(_readNotificationsKey, readIds);
  }

  static Future<void> deleteNotification(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> deletedIds = prefs.getStringList(_deletedNotificationsKey) ?? [];
    if (!deletedIds.contains(notificationId)) {
      deletedIds.add(notificationId);
      await prefs.setStringList(_deletedNotificationsKey, deletedIds);
    }
  }

  static Future<void> deleteAllNotifications(List<String> notificationIds) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> deletedIds = prefs.getStringList(_deletedNotificationsKey) ?? [];
    deletedIds.addAll(notificationIds.where((id) => !deletedIds.contains(id)));
    await prefs.setStringList(_deletedNotificationsKey, deletedIds);
  }

  static Future<List<String>> getReadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_readNotificationsKey) ?? [];
  }

  static Future<List<String>> getDeletedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_deletedNotificationsKey) ?? [];
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_readNotificationsKey);
    await prefs.remove(_deletedNotificationsKey);
  }
}