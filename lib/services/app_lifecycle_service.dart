import 'package:flutter/material.dart';
import 'package:cnattendance/services/local_notification_service.dart';
import 'package:cnattendance/services/presence_sync_service.dart';
import 'package:cnattendance/services/realtime_chat_service.dart';
import 'package:cnattendance/services/wifi_polling_manager.dart';
// REMOVED: GlobalMessagePollingService - using FCM only for notifications

/// Service to handle app lifecycle events and background notification management
class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  bool _isAppInBackground = false;
  bool _isInitialized = false;

  /// Initialize the lifecycle service
  void initialize() {
    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
      print('✅ AppLifecycleService initialized');
    }
  }

  /// Dispose the lifecycle service
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      print('🔄 AppLifecycleService disposed');
    }
  }

  /// Check if app is currently in background
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

  /// Called when app comes to foreground
  void _onAppResumed() {
    RealtimeChatService.setUserOnlineStatus(true).catchError((e) {
      print('⚠️ Error setting user online: $e');
    });
    PresenceSyncService.startForegroundSync();
    PresenceSyncService.markOnlineViaBackend().catchError((e) {
      print('⚠️ Error syncing online presence to backend: $e');
    });

    // Resume WiFi polling when app comes to foreground
    WifiPollingManager().resumePolling().catchError((e) {
      print('⚠️ Error resuming WiFi polling: $e');
    });

    // REMOVED: Global background polling - notifications come from FCM only
    // Stop global background polling when app is in foreground
    // GlobalMessagePollingService().stopBackgroundPolling();

    // Do NOT auto-clear chat notifications on app resume.
    // Users expect notifications to remain visible until they interact.
    // If needed, clear notifications explicitly from chat screens or on notification tap.
  }

  /// Called when app goes to background
  void _onAppBackgrounded() {
    RealtimeChatService.setUserOnlineStatus(false).catchError((e) {
      print('⚠️ Error setting user offline: $e');
    });
    PresenceSyncService.stopForegroundSync();

    // Pause WiFi polling when app goes to background to save battery
    WifiPollingManager().pausePolling().catchError((e) {
      print('⚠️ Error pausing WiFi polling: $e');
    });

    // REMOVED: Global background polling - notifications come from FCM only
    // Start global background polling when app goes to background
    // GlobalMessagePollingService().startBackgroundPolling();
  }

  /// Clear chat notifications when user returns to app
  Future<void> _clearChatNotifications() async {
    try {
      // Get all pending notifications
      final pendingNotifications = await LocalNotificationService.getPendingNotifications();
      
      // Cancel chat-related notifications
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

  /// Show a background notification only if app is in background
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
    
    // Only show notification if app is in background
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
      print('💡 To test notifications, minimize the app and send a message from another device');
    }
  }

  /// Force show notification regardless of app state (for testing)
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