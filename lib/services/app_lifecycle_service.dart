import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cnattendance/services/local_notification_service.dart';
import 'package:cnattendance/services/wifi_polling_manager.dart';

/// App lifecycle coordination for WiFi polling.
/// Android: foreground polling pauses in background (background service continues).
/// iOS: foreground polling continues (background service supplements with iOS background time).
class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  bool _isAppInBackground = false;
  bool _isInitialized = false;

  void initialize() {
    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
      print('✅ AppLifecycleService initialized');
    }
  }

  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      print('🔄 AppLifecycleService disposed');
    }
  }

  bool get isAppInBackground => _isAppInBackground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInBackground = false;
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _isAppInBackground = true;
        _onAppBackgrounded();
        break;
      case AppLifecycleState.hidden:
        _isAppInBackground = true;
        break;
    }
  }

  void _onAppResumed() {
    print('✅ App resumed — resuming foreground WiFi polling');

    if (Platform.isAndroid) {
      WifiPollingManager().resumePolling();
    }

    // Refresh dashboard state after returning from background.
    WifiPollingManager().forceCheck();
  }

  void _onAppBackgrounded() {
    print('✅ App backgrounded — background WiFi service continues');

    // Avoid duplicate polling: Android background service handles BSSID sync.
    if (Platform.isAndroid) {
      WifiPollingManager().pausePolling();
    }
  }

  Future<void> _clearChatNotifications() async {
    try {
      final pendingNotifications =
          await LocalNotificationService.getPendingNotifications();

      for (final notification in pendingNotifications) {
        if (notification.payload?.contains('chat_message') == true ||
            notification.payload?.contains('project_chat_message') == true) {
          await LocalNotificationService.cancelNotification(notification.id);
        }
      }

      print('🔔 Cleared ${pendingNotifications.length} chat notifications');
    } catch (e) {
      print('❌ Failed to clear chat notifications: $e');
    }
  }

  static Future<void> showBackgroundNotificationIfNeeded({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final service = AppLifecycleService();

    print('🔔 Notification request - App in background: ${service.isAppInBackground}');
    print('🔔 Title: $title');
    print('🔔 Body: $body');

    if (service.isAppInBackground) {
      await LocalNotificationService.showBackgroundNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
      print('🔔 Background notification shown: $title');
    } else {
      print('📱 App in foreground - skipping notification: $title');
    }
  }

  static Future<void> forceShowNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await LocalNotificationService.showBackgroundNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
    print('🔔 Force notification shown: $title');
  }
}
