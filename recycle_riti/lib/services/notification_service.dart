import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  // Set up Firebase messaging to listen for incoming notifications
  static void setupFirebaseMessaging(Function(String) onMessageReceived) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final requestId = message.data['requestId'];
        if (requestId != null) {
          onMessageReceived(requestId);
        }
      }
    });
  }

  // Send a notification to all agents about a new pickup request
  static Future<void> sendNotificationToAllAgents(String requestId) async {
    try {
      const String serverKey = 'YOUR_FCM_SERVER_KEY'; // Replace with your FCM server key
      const String fcmUrl = 'https://fcm.googleapis.com/fcm/send';

      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': '/topics/agents',
          'notification': {
            'title': 'New Pickup Request',
            'body': 'A new pickup request (ID: $requestId) is available!',
          },
          'data': {
            'requestId': requestId,
          },
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to send notification to agents: ${response.body}');
      } else {
        print('Successfully sent notification to agents for request $requestId');
      }
    } catch (e) {
      print('Error sending notification to agents: $e');
    }
  }

  // Send a cancellation notification to the user
  static Future<void> sendCancellationNotificationToUser(String userId, String requestId) async {
    try {
      const String serverKey = 'YOUR_FCM_SERVER_KEY'; // Replace with your FCM server key
      const String fcmUrl = 'https://fcm.googleapis.com/fcm/send';

      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': '/topics/user_$userId', // Topic specific to the user
          'notification': {
            'title': 'Pickup Request Cancelled',
            'body': 'Sorry your requested pickup has unfortunately been cancelled! Apologies for the inconvenience. You can always schedule your next pickup anytime!',
          },
          'data': {
            'requestId': requestId,
            'type': 'cancellation',
          },
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to send cancellation notification to user $userId: ${response.body}');
      } else {
        print('Successfully sent cancellation notification to user $userId for request $requestId');
      }
    } catch (e) {
      print('Error sending cancellation notification to user $userId: $e');
    }
  }

  // Send a cancellation notification to the agent
  static Future<void> sendCancellationNotificationToAgent(String agentId, String requestId) async {
    try {
      const String serverKey = 'YOUR_FCM_SERVER_KEY'; // Replace with your FCM server key
      const String fcmUrl = 'https://fcm.googleapis.com/fcm/send';

      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': '/topics/agent_$agentId', // Topic specific to the agent
          'notification': {
            'title': 'Pickup Request Cancelled',
            'body': 'Sorry to inform you that the pickup has been cancelled! Apologies for the inconvenience.',
          },
          'data': {
            'requestId': requestId,
            'type': 'cancellation',
          },
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to send cancellation notification to agent $agentId: ${response.body}');
      } else {
        print('Successfully sent cancellation notification to agent $agentId for request $requestId');
      }
    } catch (e) {
      print('Error sending cancellation notification to agent $agentId: $e');
    }
  }
}