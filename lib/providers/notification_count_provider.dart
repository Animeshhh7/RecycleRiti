import 'package:flutter/material.dart';
import 'package:recycle_riti/view/notification_screen.dart';

class NotificationCountProvider with ChangeNotifier {
  int _notificationCount = 0;
  bool _isUpdating = false;
  DateTime? _lastUpdateTime;
  static const Duration _debounceDuration = Duration(seconds: 2);

  int get notificationCount => _notificationCount;

  NotificationCountProvider() {
    _initializeCount();
  }

  Future<void> _initializeCount() async {
    try {
      print('NotificationCountProvider - Initializing notification count');
      await updateNotificationCount();
    } catch (e) {
      print('NotificationCountProvider - Error initializing count: $e');
    }
  }

  Future<void> updateNotificationCount() async {
    if (_isUpdating) {
      print('NotificationCountProvider - Update already in progress, skipping');
      return;
    }

    final now = DateTime.now();
    if (_lastUpdateTime != null && now.difference(_lastUpdateTime!) < _debounceDuration) {
      print('NotificationCountProvider - Debouncing update, last update was at $_lastUpdateTime');
      return;
    }

    _isUpdating = true;
    try {
      print('NotificationCountProvider - Fetching notification count');
      final newCount = await NotificationScreen.getNotificationCount();
      if (_notificationCount != newCount) {
        _notificationCount = newCount;
        print('NotificationCountProvider - Updated notification count to $_notificationCount');
        notifyListeners();
      } else {
        print('NotificationCountProvider - Notification count unchanged: $_notificationCount');
      }
      _lastUpdateTime = now;
    } catch (e) {
      print('NotificationCountProvider - Error updating notification count: $e');
    } finally {
      _isUpdating = false;
    }
  }

  void resetCount() {
    _notificationCount = 0;
    _lastUpdateTime = null;
    print('NotificationCountProvider - Reset notification count to 0');
    notifyListeners();
  }
}// 11125
