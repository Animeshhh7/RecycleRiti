// lib/api/rest_auth.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:recycle_riti/routes/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String baseUrl = dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:5000/api';
  static const int maxRetries = 2; // Maximum number of retries for network requests

  static Future<void> testBackend() async {
    try {
      final result = await InternetAddress.lookup('10.0.2.2').timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('Host 10.0.2.2 is reachable');
      } else {
        print('Host 10.0.2.2 not reachable');
      }
      final res = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      print('Backend health: ${res.statusCode} - ${res.body}');
    } catch (e) {
      print('Backend test failed: $e');
      if (e.toString().contains('TimeoutException')) {
        print('Timeout: Check if backend is running');
      }
    }
  }

  static Future<Map<String, dynamic>> registerUser(
    String username,
    String email,
    String password,
    String phone, {
    String role = 'user', // Default role
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim(),
          'password': password.trim(),
          'phone': phone.trim(),
          'role': role,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', data['accessToken'] ?? '');
        await prefs.setString('refreshToken', data['refreshToken'] ?? '');
        return data;
      }
      throw Exception(data['message'] ?? 'Signup failed. Please try again.');
    } catch (e) {
      throw Exception('Signup failed. Please check your connection and try again.');
    }
  }

  static Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      print('Login response: ${res.statusCode} - ${res.body}');
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        if (!data.containsKey('accessToken') || !data.containsKey('refreshToken')) {
          print('Login response missing tokens: $data');
          throw Exception('Login failed: Backend did not return tokens');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', data['accessToken'] ?? '');
        await prefs.setString('refreshToken', data['refreshToken'] ?? '');

        final savedAccessToken = prefs.getString('accessToken');
        final savedRefreshToken = prefs.getString('refreshToken');
        print('Tokens saved - Access token exists: ${savedAccessToken != null}, Refresh token exists: ${savedRefreshToken != null}');
        if (savedAccessToken == null || savedRefreshToken == null) {
          throw Exception('Failed to save tokens in SharedPreferences');
        }

        return data;
      }
      throw Exception(data['message'] ?? 'Login failed. Please try again.');
    } catch (e) {
      print('Login error: $e');
      throw Exception('Login failed. Please check your connection and try again.');
    }
  }

  static Future<void> refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rToken = prefs.getString('refreshToken');
      if (rToken == null || rToken.isEmpty) {
        print('No refresh token found in SharedPreferences');
        throw Exception('No refresh token');
      }
      print('Attempting to refresh token');
      final res = await http.post(
        Uri.parse('$baseUrl/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': rToken}),
      ).timeout(const Duration(seconds: 30));

      print('Refresh token response: ${res.statusCode} - ${res.body}');
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await prefs.setString('accessToken', data['accessToken'] ?? '');
        print('New access token saved');
      } else {
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
        print('Token refresh failed: ${data['message'] ?? 'Unknown error'}');
        throw Exception(data['message'] ?? 'Token refresh failed');
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      print('Token refresh error: $e');
      throw Exception('Token refresh failed. Please login again.');
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rToken = prefs.getString('refreshToken');
      final res = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': rToken}),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
        print('Tokens cleared during logout');
        return data;
      }
      throw Exception(data['message'] ?? 'Logout failed');
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      print('Tokens cleared during logout (error case)');
      throw Exception('Logout failed: $e');
    }
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null || token.isEmpty) {
      print('No access token found in SharedPreferences');
      return null;
    }

    final parts = token.split('.');
    if (parts.length != 3) {
      print('Invalid token structure: $token');
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      return null;
    }

    try {
      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      print('Padded payload: $payload');
      final decodedPayload = base64Url.decode(payload);
      final payloadJson = utf8.decode(decodedPayload);
      print('Decoded payload: $payloadJson');
      final payloadData = jsonDecode(payloadJson);
      final exp = payloadData['exp'] as int?;
      if (exp != null) {
        final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (expirationDate.isBefore(DateTime.now())) {
          print('Token expired at: $expirationDate');
          await refreshAccessToken();
          return prefs.getString('accessToken');
        } else {
          print('Token is valid until: $expirationDate');
        }
      } else {
        print('No expiration found in token payload');
      }
    } catch (e) {
      print('Error decoding token: $e');
      print('Proceeding with token despite decoding error');
    }

    return token;
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  static Future<http.Response> makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('No internet connection. Please check your network.');
        }
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          throw Exception('No internet connection after $maxRetries attempts. Please check your network.');
        }
        print('Internet connection check failed. Retrying ($retryCount/$maxRetries)...');
        await Future.delayed(Duration(seconds: 2));
        continue;
      }

      final prefs = await SharedPreferences.getInstance();
      var token = await getAccessToken();
      if (token == null) {
        print('No access token found in SharedPreferences');
        throw Exception('No token. Please login.');
      }

      print('Making $method request to $endpoint');
      var headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      http.Response res;
      try {
        if (method == 'GET') {
          res = await http.get(
            Uri.parse('$baseUrl/$endpoint'),
            headers: headers,
          ).timeout(timeout);
        } else if (method == 'POST') {
          res = await http.post(
            Uri.parse('$baseUrl/$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          ).timeout(timeout);
        } else if (method == 'PUT') {
          res = await http.put(
            Uri.parse('$baseUrl/$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          ).timeout(timeout);
        } else if (method == 'DELETE') {
          res = await http.delete(
            Uri.parse('$baseUrl/$endpoint'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);
        } else {
          throw Exception('Unsupported HTTP method: $method');
        }

        print('Response from $endpoint: ${res.statusCode} - ${res.body}');
        if (res.statusCode == 401 || (res.statusCode == 403 && res.body.contains('Token'))) {
          print('Token expired or unauthorized. Attempting to refresh token...');
          try {
            await refreshAccessToken();
            token = await getAccessToken();
            if (token == null) {
              throw Exception('Failed to refresh token: No new token available');
            }
            headers['Authorization'] = 'Bearer $token';
            print('Retrying $method request to $endpoint');
            if (method == 'GET') {
              res = await http.get(
                Uri.parse('$baseUrl/$endpoint'),
                headers: headers,
              ).timeout(timeout);
            } else if (method == 'POST') {
              res = await http.post(
                Uri.parse('$baseUrl/$endpoint'),
                headers: headers,
                body: jsonEncode(body),
              ).timeout(timeout);
            } else if (method == 'PUT') {
              res = await http.put(
                Uri.parse('$baseUrl/$endpoint'),
                headers: headers,
                body: jsonEncode(body),
              ).timeout(timeout);
            } else if (method == 'DELETE') {
              res = await http.delete(
                Uri.parse('$baseUrl/$endpoint'),
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              ).timeout(timeout);
            }
            print('Retry response from $endpoint: ${res.statusCode} - ${res.body}');
          } catch (e) {
            print('Token refresh failed: $e');
            await prefs.remove('accessToken');
            await prefs.remove('refreshToken');
            throw Exception('Session expired. Please login again. Error: $e');
          }
        }

        if (res.statusCode == 404) {
          final data = jsonDecode(res.body);
          throw Exception(data['message'] ?? 'Resource not found');
        }

        if (res.statusCode != 200 && res.statusCode != 201) {
          try {
            final data = jsonDecode(res.body);
            if (data['message']?.toLowerCase().contains('bad token') ?? false) {
              await prefs.remove('accessToken');
              await prefs.remove('refreshToken');
              throw Exception('Bad token. Please login again.');
            }
            throw Exception(data['message'] ?? 'Request failed. Please try again.');
          } catch (e) {
            throw Exception('Request failed: Invalid response from server.');
          }
        }

        return res;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          throw Exception('Request failed after $maxRetries attempts: $e');
        }
        print('Request to $endpoint failed. Retrying ($retryCount/$maxRetries)...');
        await Future.delayed(Duration(seconds: 2));
      }
    }
    throw Exception('Request failed after $maxRetries attempts.');
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final res = await makeRequest('GET', 'auth/profile');
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      print('Get user profile error: $e');
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    try {
      // Validate file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: ${imageFile.path}');
      }

      final ext = path.extension(imageFile.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png'].contains(ext)) {
        throw Exception('Only jpg, jpeg, png allowed');
      }

      final token = await getAccessToken();
      if (token == null) {
        throw Exception('No token. Please login.');
      }

      // Log file details
      final fileSize = await imageFile.length();
      print('Uploading image: ${imageFile.path}, Size: ${fileSize ~/ 1024} KB');

      // Determine content type
      final contentType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      print('Image content type: $contentType');

      // Read the file as bytes and encode to base64
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final imageBase64 = 'data:$contentType;base64,$base64String';
      print('Base64 image length: ${imageBase64.length}');

      // Send the base64 string as JSON
      final body = {
        'imageBase64': imageBase64,
      };

      final res = await makeRequest('POST', 'auth/update-profile-image', body: body);
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      print('Error uploading profile image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? phone,
    String? email,
  }) async {
    try {
      final res = await makeRequest(
        'PUT',
        'auth/update-profile',
        body: {
          if (username != null && username.trim().isNotEmpty) 'username': username.trim(),
          'phone': phone ?? '',
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        },
      );
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      throw Exception('Failed to update profile. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> schedulePickup(Map<String, dynamic> pickupData) async {
    try {
      final quantity = pickupData['quantity'] as int?;
      final pickupDate = pickupData['pickupDate'] != null ? DateTime.parse(pickupData['pickupDate']) : null;
      final recyclableTypeId = pickupData['recyclableTypeId'] as int?;
      final frequency = pickupData['frequency'] as String?;
      final location = pickupData['location'] as String?;

      if (quantity == null || quantity <= 0) {
        throw Exception('Quantity must be greater than 0');
      }
      if (pickupDate == null || pickupDate.isBefore(DateTime.now())) {
        throw Exception('Pickup date must be in the future');
      }
      if (recyclableTypeId == null) {
        throw Exception('Recyclable type is required');
      }
      if (frequency == null || frequency.trim().isEmpty) {
        throw Exception('Frequency is required');
      }
      if (location == null || location.trim().isEmpty) {
        throw Exception('Location is required');
      }

      final res = await makeRequest(
        'POST',
        'pickup/schedule',
        body: {
          'recyclableTypeId': recyclableTypeId,
          'quantity': quantity,
          'pickupDate': pickupDate.toUtc().toIso8601String(),
          'frequency': frequency.trim(),
          'location': location.trim(),
        },
      );
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      if (e.toString().contains('Fill all fields')) {
        throw Exception('Please fill all required fields');
      } else if (e.toString().contains('Quantity must be more than 0')) {
        throw Exception('Quantity must be greater than 0');
      } else if (e.toString().contains('Pick a future date')) {
        throw Exception('Please select a future date for pickup');
      } else if (e.toString().contains('Type not found')) {
        throw Exception('Selected recyclable type not found');
      } else if (e.toString().contains('Session expired')) {
        throw Exception('Your session has expired. Please log in again.');
      }
      throw Exception('Unable to schedule pickup. Please try again. Error: $e');
    }
  }

  static Future<Map<String, dynamic>> getPickupRequests() async {
    try {
      final res = await makeRequest('GET', 'pickup/requests');
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      throw Exception('Failed to fetch pickup requests. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> getAgentPickupRequests() async {
    try {
      final res = await makeRequest('GET', 'pickup/requests');
      final data = jsonDecode(res.body);
      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Failed to fetch agent pickup requests');
      }

      // Fetch the user profile to get the current agent's ID
      final profile = await getUserProfile();
      final currentAgentId = profile['user']['id'].toString();

      // Filter requests assigned to the agent or pending requests that can be assigned
      final agentRequests = (data['pickupRequests'] as List<dynamic>?)?.where((request) {
        final isPending = (request['status']?.toString().toLowerCase() ?? '') == 'pending' && request['agent'] == null;
        final isAssigned = request['agent'] != null && request['agent']['id'].toString() == currentAgentId;
        return isPending || isAssigned;
      }).toList();

      return {
        'success': true,
        'pickupRequests': agentRequests ?? [],
      };
    } catch (e) {
      throw Exception('Failed to fetch agent pickup requests. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> trackPickupRequest(String requestId) async {
    try {
      final res = await makeRequest('GET', 'pickup/track/$requestId');
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      if (e.toString().contains('Request not found')) {
        throw Exception('Pickup request not found');
      }
      throw Exception('Failed to track pickup request. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> cancelPickupRequest(String requestId) async {
    try {
      // Fetch the user's profile to determine their role
      final profile = await getUserProfile();
      final role = profile['user']['role'] ?? 'user';
      final userId = profile['user']['id'].toString();

      // Fetch the request to verify ownership or assignment
      final trackResponse = await trackPickupRequest(requestId);
      final request = trackResponse['pickupRequest'];
      final requestStatus = request['status']?.toLowerCase() ?? '';
      final requestUserId = request['user']['id'].toString();
      final requestAgentId = request['agent'] != null ? request['agent']['id'].toString() : null;

      // Validate cancellation permissions
      if (role == 'user' && requestUserId != userId) {
        throw Exception('Not authorized to cancel this request');
      }
      if (role == 'agent' && requestAgentId != userId) {
        throw Exception('Not authorized to cancel this request');
      }
      if (!['pending', 'accepted'].contains(requestStatus)) {
        throw Exception('Cannot cancel a request that is already completed or cancelled');
      }

      final res = await makeRequest('PUT', 'pickup/cancel/$requestId');
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      if (e.toString().contains('Request not found')) {
        throw Exception('Pickup request not found');
      } else if (e.toString().contains('Not authorized')) {
        throw Exception('Not authorized to cancel this request');
      } else if (e.toString().contains('Cannot cancel')) {
        throw Exception('Cannot cancel this request');
      }
      throw Exception('Failed to cancel pickup request. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> markPickupAsCompleted(String requestId) async {
    try {
      // Fetch the user's profile to determine their role
      final profile = await getUserProfile();
      final role = profile['user']['role'] ?? 'user';
      final userId = profile['user']['id'].toString();

      // Fetch the request to verify assignment
      final trackResponse = await trackPickupRequest(requestId);
      final request = trackResponse['pickupRequest'];
      final requestStatus = request['status']?.toLowerCase() ?? '';
      final requestAgentId = request['agent'] != null ? request['agent']['id'].toString() : null;

      // Validate completion permissions
      if (role != 'agent') {
        throw Exception('Only agents can mark requests as completed');
      }
      if (requestAgentId != userId) {
        throw Exception('Not authorized to complete this request');
      }
      if (requestStatus != 'accepted') {
        throw Exception('Only accepted requests can be marked as completed');
      }

      final res = await makeRequest('PUT', 'pickup/complete/$requestId', body: {});
      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      if (e.toString().contains('Request not found')) {
        throw Exception('Pickup request not found');
      } else if (e.toString().contains('Only accepted requests')) {
        throw Exception('Only accepted requests can be marked as completed');
      } else if (e.toString().contains('Not authorized')) {
        throw Exception('Not authorized to complete this request');
      }
      throw Exception('Failed to mark pickup request as completed. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> getRecyclableTypes() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/recyclable-types'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to fetch recyclable types');
    } catch (e) {
      throw Exception('Failed to fetch recyclable types. Please try again.');
    }
  }

  Future<String> getInitialRoute() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        final profile = await getUserProfile();
        if (profile['success']) {
          final role = profile['user']['role'] ?? 'user';
          print('User role: $role');
          print('Navigating to ${role == 'agent' ? 'agent' : 'main'} after successful token check');
          return role == 'agent' ? AppRoutes.agent : AppRoutes.main;
        }
      }
    } catch (e) {
      print('Error checking auth state: $e');
    }
    return AppRoutes.login;
  }
}