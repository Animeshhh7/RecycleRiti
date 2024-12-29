import 'package:flutter/material.dart';
import 'package:recycle_riti/routes/routes.dart';

class ExceptionHandling {
  // Displays a snackbar with a message and an optional retry action
  static void showSnackBar(BuildContext context, String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14, color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        action: onRetry != null
            ? SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: onRetry)
            : null,
      ),
    );
  }

  // Checks if an error indicates a session-related issue
  static bool isSessionInvalidError(String error) {
    return error.contains('Session expired') ||
        error.contains('No access token available') ||
        error.contains('Bad token') ||
        error.contains('User not found');
  }

  // Handles session invalidation by redirecting to the login screen
  static void handleSessionInvalid(BuildContext context, String message) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (Route<dynamic> route) => false);
    showSnackBar(context, message);
  }

  // Generic method to handle API calls with try-catch
  static Future<T> handleApiCall<T>(
    BuildContext context,
    Future<T> Function() apiCall, {
    required String defaultErrorMessage,
    VoidCallback? retryCallback,
    required Function(T) onSuccess,
    Function(String)? onError,
  }) async {
    try {
      final result = await apiCall();
      onSuccess(result);
      return result;
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (isSessionInvalidError(e.toString())) {
        handleSessionInvalid(context, 'Session invalid. Please log in again.');
      } else {
        if (onError != null) {
          onError(errorMessage);
        }
        showSnackBar(context, '$defaultErrorMessage: $errorMessage', onRetry: retryCallback);
      }
      rethrow; // Rethrow to allow caller to handle the exception if needed
    }
  }

  // Handles API calls that don't return a value (e.g., DELETE, PUT requests)
  static Future<void> handleVoidApiCall(
    BuildContext context,
    Future<void> Function() apiCall, {
    required String defaultErrorMessage,
    VoidCallback? retryCallback,
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) async {
    try {
      await apiCall();
      if (onSuccess != null) {
        onSuccess();
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (isSessionInvalidError(e.toString())) {
        handleSessionInvalid(context, 'Session invalid. Please log in again.');
      } else {
        if (onError != null) {
          onError(errorMessage);
        }
        showSnackBar(context, '$defaultErrorMessage: $errorMessage', onRetry: retryCallback);
      }
      rethrow;
    }
  }
}// 23849
