import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:get/get.dart';
import 'package:cnattendance/screen/profile/chatscreen.dart';
import 'package:cnattendance/screens/chat/project_chat_screen.dart';
import 'package:cnattendance/services/project_service.dart';

/// Local notification service using flutter_local_notifications
/// Configured specifically for background notifications
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Channel IDs for different notification types
  static const String _backgroundChannelId = 'background_notifications';
  static const String _backgroundChannelName = 'Background Notifications';
  static const String _backgroundChannelDescription =
      'Notifications that appear in background mode';

  static const String _foregroundChannelId = 'foreground_notifications';
  static const String _foregroundChannelName = 'Foreground Notifications';
  static const String _foregroundChannelDescription =
      'Notifications that appear when app is active';

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔔 Initializing LocalNotificationService...');

      // Initialize timezone database
      tz.initializeTimeZones();

      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Combined initialization settings
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // Initialize the plugin
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }

      // Request permissions
      await _requestPermissions();

      _isInitialized = true;
      print('✅ LocalNotificationService initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize LocalNotificationService: $e');
    }
  }

  /// Create notification channels for Android
  static Future<void> _createNotificationChannels() async {
    try {
      // Background notification channel - MAX importance for background visibility
      const AndroidNotificationChannel backgroundChannel =
          AndroidNotificationChannel(
        _backgroundChannelId,
        _backgroundChannelName,
        description: _backgroundChannelDescription,
        importance:
            Importance.max, // Maximum importance for background notifications
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFF9D50DD),
        showBadge: true,
        // sound: RawResourceAndroidNotificationSound('notification'), // Comment out if audio file doesn't exist
      );

      // Foreground notification channel - DEFAULT importance
      const AndroidNotificationChannel foregroundChannel =
          AndroidNotificationChannel(
        _foregroundChannelId,
        _foregroundChannelName,
        description: _foregroundChannelDescription,
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      );

      // Create the channels
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(backgroundChannel);

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(foregroundChannel);

      // Also create a channel that matches the AndroidManifest default id
      // Some devices / FCM flows use the manifest-default channel id, so
      // create it here to avoid missing notifications.
      const AndroidNotificationChannel manifestDefaultChannel =
          AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Default channel used by FCM (manifest)',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(manifestDefaultChannel);

      print('✅ Notification channels created successfully');
    } catch (e) {
      print('❌ Failed to create notification channels: $e');
    }
  }

  /// Request notification permissions
  static Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        final bool? granted =
            await androidImplementation?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();

        final bool? granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      print('❌ Failed to request permissions: $e');
      return false;
    }
  }

  /// Show a background notification (appears even when app is in background)
  static Future<void> showBackgroundNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool ongoing = false,
  }) async {
    try {
      await _ensureInitialized();

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        _backgroundChannelId,
        _backgroundChannelName,
        channelDescription: _backgroundChannelDescription,
        importance:
            Importance.max, // Maximum importance for background visibility
        priority: Priority.high, // High priority for immediate display
        ticker: title,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'New Message',
        ),
        playSound: true,
        // sound: const RawResourceAndroidNotificationSound('notification'), // Comment out if audio file doesn't exist
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        enableLights: true,
        color: const Color(0xFF9D50DD),
        ledColor: const Color(0xFF9D50DD),
        ledOnMs: 1000,
        ledOffMs: 500,
        ongoing: ongoing, // Makes notification persistent if true
        autoCancel: !ongoing,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        usesChronometer: false,
        fullScreenIntent: false,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        // Additional settings for better background display
        setAsGroupSummary: false,
        groupKey: 'digital_hr_notifications',
        showProgress: false,
        maxProgress: 0,
        progress: 0,
        indeterminate: false,
        channelShowBadge: true,
        onlyAlertOnce: false,
        timeoutAfter: null, // No timeout
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      print('✅ Background notification shown: $title');
    } catch (e) {
      print('❌ Failed to show background notification: $e');
    }
  }

  /// Show a foreground notification (normal priority)
  static Future<void> showForegroundNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _ensureInitialized();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        _foregroundChannelId,
        _foregroundChannelName,
        channelDescription: _foregroundChannelDescription,
        importance: Importance.defaultImportance,
        ticker: 'ticker',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      print('✅ Foreground notification shown: $title');
    } catch (e) {
      print('❌ Failed to show foreground notification: $e');
    }
  }

  /// Show notification from Firebase message with background configuration
  static Future<void> showNotificationFromFirebaseMessage(
    RemoteMessage message, {
    bool forceBackground = true,
  }) async {
    try {
      final String title = message.notification?.title ?? 'New Message';
      final String body =
          message.notification?.body ?? 'You have a new message';
      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      // Prepare payload with message data as JSON string
      final String payload = json.encode(message.data);

      print('📱 Creating notification with payload: $payload');

      if (forceBackground) {
        await showBackgroundNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        );
      } else {
        await showForegroundNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        );
      }
    } catch (e) {
      print('❌ Failed to show notification from Firebase message: $e');
    }
  }

  /// Schedule a background notification
  static Future<void> scheduleBackgroundNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      await _ensureInitialized();

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        _backgroundChannelId,
        _backgroundChannelName,
        channelDescription: _backgroundChannelDescription,
        importance: Importance.high,
        styleInformation: BigTextStyleInformation(body),
        enableVibration: true,
        enableLights: true,
        color: const Color(0xFF9D50DD),
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      print('✅ Background notification scheduled for: $scheduledDate');
    } catch (e) {
      print('❌ Failed to schedule background notification: $e');
    }
  }

  /// Cancel a notification
  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      print('✅ Notification cancelled: $id');
    } catch (e) {
      print('❌ Failed to cancel notification: $e');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      print('✅ All notifications cancelled');
    } catch (e) {
      print('❌ Failed to cancel all notifications: $e');
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      print('🔔 Notification tapped with payload: $payload');
      // Handle navigation or other actions based on payload
      _handleNotificationPayload(payload);
    }
  }

  /// Handle notification payload
  static void _handleNotificationPayload(String payload) {
    final navigationStartTime = DateTime.now();
    try {
      print('📱 Handling notification payload: $payload');
      print('⏱️  Navigation start time: $navigationStartTime');

      Map<String, dynamic> data = {};

      // Try to parse as JSON first (for new format)
      try {
        data = json.decode(payload);
        print('📱 Parsed as JSON: $data');
      } catch (e) {
        // Fallback: Try Map.toString() format
        print('⚠️ Not JSON, trying map format parse');
        data = _parseMapString(payload);
        print('📱 Parsed as map string: $data');
      }

      // Navigate based on type
      final type = data['type']?.toString();
      if (type == null || type.isEmpty) {
        print('❌ No type found in payload');
        return;
      }

      print('📱 Notification type: $type');

      // Handle group_chat_message as group_chat
      if (type == 'project_chat' ||
          type == 'group_chat' ||
          type == 'group_chat_message') {
        print('🎯 Routing to project chat');
        _navigateToProjectChat(data, navigationStartTime);
      } else if (type == 'chat' || type == 'message') {
        print('🎯 Routing to direct chat');
        _navigateToDirectChat(data, navigationStartTime);
      } else {
        print('❌ Unknown notification type: $type');
      }
    } catch (e) {
      print('❌ Failed to handle notification payload: $e');
    }
  }

  /// Parse map-like string format: {key1: value1, key2: value2}
  static Map<String, dynamic> _parseMapString(String payload) {
    final Map<String, dynamic> map = {};

    // Remove surrounding braces if any
    var str = payload.trim();
    if (str.startsWith('{') && str.endsWith('}')) {
      str = str.substring(1, str.length - 1);
    }

    // Split by comma and parse key-value pairs
    final pairs = str.split(', ');
    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex > 0) {
        final key = pair.substring(0, colonIndex).trim();
        final value = pair.substring(colonIndex + 1).trim();
        map[key] = value;
      }
    }

    return map;
  }

  /// Navigate to project chat with safe navigation
  static Future<void> _navigateToProjectChat(
      Map<String, dynamic> data, DateTime navigationStartTime) async {
    try {
      print('🎯 Starting project chat navigation');
      print('📋 Data: $data');

      String? projectId = data['project_id']?.toString();
      String? conversationId = data['conversation_id']?.toString();
      String? conversationName = data['conversation_name']?.toString();
      String? projectName = data['project_name']?.toString();

      print(
          '📋 Extracted: projectId=$projectId, conversationId=$conversationId, conversationName=$conversationName, projectName=$projectName');

      // Use conversation_name as project name if project_name not available
      final finalProjectName = projectName ?? conversationName;
      final parsedProjectId = int.tryParse(projectId ?? '') ?? 0;

      if (conversationId != null && finalProjectName != null) {
        print(
            '📱 Navigating to project chat: $finalProjectName (Conversation: $conversationId)');

        int parsedConversationId = int.tryParse(conversationId) ?? 0;
        if (parsedConversationId > 0) {
          // SAFE NAVIGATION: Wait for navigator to be ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.to(
              () => ProjectChatScreen(
                projectId: parsedProjectId,
                projectName: finalProjectName,
                leaders: [],
                members: [],
                conversationId: parsedConversationId,
              ),
            );
            final navEndTime = DateTime.now();
            final navTotalDuration =
                navEndTime.difference(navigationStartTime).inMilliseconds;
            print(
                '✅ Project chat navigation completed in ${navTotalDuration}ms');
          });
          return;
        }

        print('⚠️ Conversation ID invalid, navigating without it');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.to(
            () => ProjectChatScreen(
              projectId: parsedProjectId,
              projectName: finalProjectName,
              leaders: [],
              members: [],
            ),
          );
          final fallbackNavEnd = DateTime.now();
          final fallbackNavDuration =
              fallbackNavEnd.difference(navigationStartTime).inMilliseconds;
          print(
              '✅ Project chat navigation completed in ${fallbackNavDuration}ms');
        });
      } else {
        print(
            '❌ Missing required data for navigation: conversationId=$conversationId, projectName=$finalProjectName');
      }
    } catch (e) {
      print('❌ Error navigating to project chat: $e');
    }
  }

  /// Navigate to direct chat with safe navigation
  static void _navigateToDirectChat(
      Map<String, dynamic> data, DateTime navigationStartTime) {
    try {
      String? senderName = data['sender_name']?.toString();
      String? senderImage = data['sender_image']?.toString();
      String? senderUsername = data['sender_username']?.toString();

      if (senderName != null && senderUsername != null) {
        print('📱 Navigating to direct chat with: $senderName');

        // SAFE NAVIGATION: Wait for navigator to be ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.to(
            () => ChatScreen(),
            arguments: {
              'name': senderName,
              'avatar': senderImage ?? '',
              'username': senderUsername,
            },
          );
          final directChatEnd = DateTime.now();
          final directChatTotalDuration =
              directChatEnd.difference(navigationStartTime).inMilliseconds;
          print(
              '✅ Direct chat navigation completed in ${directChatTotalDuration}ms');
        });
      } else {
        print('❌ Missing sender data for navigation');
      }
    } catch (e) {
      print('❌ Error navigating to direct chat: $e');
    }
  }

  /// Ensure service is initialized
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Get pending notifications
  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      print('❌ Failed to get pending notifications: $e');
      return [];
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await androidImplementation?.areNotificationsEnabled() ?? false;
      }
      return true; // Assume enabled for other platforms
    } catch (e) {
      print('❌ Failed to check if notifications are enabled: $e');
      return false;
    }
  }
}
