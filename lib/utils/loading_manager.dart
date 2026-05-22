import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'dart:async';

/// Helper class to manage loading states with automatic timeout
/// This prevents the app from showing loading animation indefinitely
class LoadingManager {
  static Timer? _timeoutTimer;
  static const Duration _maxLoadingDuration = Duration(seconds: 45);

  /// Show loading with automatic timeout
  /// If the loading is not manually dismissed within [maxDuration], it will auto-dismiss
  static void show({
    String? status,
    EasyLoadingMaskType maskType = EasyLoadingMaskType.black,
    Duration maxDuration = _maxLoadingDuration,
  }) {
    // Cancel any existing timeout timer
    _timeoutTimer?.cancel();

    // Show the loading indicator
    EasyLoading.show(status: status, maskType: maskType);

    // Set a timeout to automatically dismiss the loading
    _timeoutTimer = Timer(maxDuration, () {
      if (EasyLoading.isShow) {
        EasyLoading.dismiss();
        debugPrint('⏱️ LoadingManager: Auto-dismissed after timeout');
      }
    });
  }

  /// Dismiss loading and cancel the timeout timer
  static void dismiss({bool animation = true}) {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    EasyLoading.dismiss(animation: animation);
  }

  /// Check if loading is currently shown
  static bool get isShowing => EasyLoading.isShow;

  /// Execute an async operation with loading indicator and automatic timeout
  /// 
  /// Example:
  /// ```dart
  /// await LoadingManager.execute(
  ///   status: 'Loading...',
  ///   operation: () => apiCall(),
  ///   onError: (error) => print('Error: $error'),
  /// );
  /// ```
  static Future<T?> execute<T>({
    required Future<T> Function() operation,
    String? status,
    Function(dynamic error)? onError,
    Duration maxDuration = _maxLoadingDuration,
    EasyLoadingMaskType maskType = EasyLoadingMaskType.black,
  }) async {
    show(status: status, maskType: maskType, maxDuration: maxDuration);
    
    try {
      final result = await operation();
      dismiss();
      return result;
    } catch (error) {
      dismiss();
      if (onError != null) {
        onError(error);
      } else {
        rethrow;
      }
      return null;
    }
  }

  /// Show error message with SnackBar
  static void showError(BuildContext context, String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: duration,
      ),
    );
  }

  /// Show success message with SnackBar
  static void showSuccess(BuildContext context, String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: duration,
      ),
    );
  }

  /// Show info message with SnackBar
  static void showInfo(BuildContext context, String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: duration,
      ),
    );
  }

  /// Cleanup - should be called when disposing
  static void cleanup() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    if (EasyLoading.isShow) {
      EasyLoading.dismiss();
    }
  }
}
