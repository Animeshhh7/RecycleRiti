import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:recycle_riti/api/rest_auth.dart';

class NotificationService {
  static const String baseUrl = 'http://100.64.236.38:5000/api';

  static Future<void> setupFirebaseMessaging(Function(String) onMessageReceived) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      print('NotificationService - Requested permissions');

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await _registerFCMToken(fcmToken);
      } else {
        print('NotificationService - No FCM token');
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        print('NotificationService - Token refreshed: $newToken');
        await _registerFCMToken(newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('NotificationService - FCM: ${message.data}');
        if (message.notification != null) {
          print('NotificationService - Title: ${message.notification?.title}, Body: ${message.notification?.body}');
        }
        if (message.data.isNotEmpty) {
          final type = message.data['type'];
          final id = message.data['eventId'] ?? message.data['pickupId'] ?? message.data['blogId'] ?? message.data['id'];
          if (id != null) {
            print('NotificationService - Type: $type, ID: $id');
            switch (type) {
              case 'new_event':
              case 'event_cancellation':
              case 'pickup_request':
              case 'pickup_assigned':
              case 'pickup_completed':
              case 'pickup_cancelled':
              case 'pickup_deleted':
              case 'blog_approved':
              case 'blog_rejected':
                onMessageReceived(id.toString());
                break;
              default:
                print('NotificationService - Unknown type: $type');
            }
          }
        }
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      print('NotificationService - Error setting FCM: $e');
    }
  }

  static Future<void> _registerFCMToken(String fcmToken) async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final token = await AuthService.getAccessToken();
        if (token == null) {
          print('NotificationService - No auth token');
          return;
        }

        final response = await http.post(
          Uri.parse('$baseUrl/auth/update-fcm-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'fcmToken': fcmToken}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success']) {
            print('NotificationService - Registered FCM token');
            return;
          }
        }
        print('NotificationService - FCM registration error: ${response.statusCode}');
      } catch (e) {
        print('NotificationService - FCM attempt $attempt/$maxRetries: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 2));
        }
      }
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('NotificationService - Background: ${message.data}');
  }

  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final token = await AuthService.getAccessToken();
        if (token == null) {
          throw Exception('No auth token');
        }

        final response = await http.get(
          Uri.parse('$baseUrl/notifications/user'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success']) {
            print('NotificationService - Fetched ${data['notifications'].length} notifications');
            return List<Map<String, dynamic>>.from(data['notifications']);
          }
          throw Exception(data['message'] ?? 'Failed to fetch');
        }
        throw Exception('Failed to fetch: ${response.statusCode}');
      } catch (e) {
        print('NotificationService - Fetch attempt $attempt/$maxRetries: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 2));
        } else {
          throw Exception('Failed to fetch: $e');
        }
      }
    }
    throw Exception('Failed to fetch after $maxRetries attempts');
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception('No auth token');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/notifications/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'notificationId': notificationId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          print('NotificationService - Marked $notificationId as read');
          return;
        }
        throw Exception(data['message'] ?? 'Failed to mark');
      }
      throw Exception('Failed to mark: ${response.statusCode}');
    } catch (e) {
      print('NotificationService - Error marking $notificationId: $e');
      throw Exception('Failed to mark: $e');
    }
  }

  static Future<void> markNotificationsAsRead(List<String> notificationIds) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception('No auth token');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/notifications/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'notificationIds': notificationIds}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          print('NotificationService - Marked notifications: $notificationIds');
          return;
        }
        throw Exception(data['message'] ?? 'Failed to mark');
      }
      throw Exception('Failed to mark: ${response.statusCode}');
    } catch (e) {
      print('NotificationService - Error marking notifications: $e');
      throw Exception('Failed to mark: $e');
    }
  }
}// 23063
