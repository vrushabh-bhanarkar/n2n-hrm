import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/project_chat_screen.dart';
import '../model/chat/conversation.dart';
import '../screen/profile/NotificationScreen.dart';
import '../services/project_service.dart';
import '../services/chat/chat_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static Future<void>? _initializeFuture;

  // Holds notification tap that launched the app so it can be handled after navigation is ready
  static NotificationResponse? _pendingNotificationResponse;
  static bool _pendingNotificationHandled = false;
  static bool _launchedFromNotification = false;

  // Set to track processed message IDs and prevent duplicates
  static final Set<String> _processedMessageIds = {};

  // Track message subscription
  static StreamSubscription<RemoteMessage>? _messageSubscription;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    if (_initializeFuture != null) {
      return _initializeFuture!;
    }

    _initializeFuture = _initializeInternal();
    try {
      await _initializeFuture;
      _isInitialized = true;
    } finally {
      _initializeFuture = null;
    }
  }

  static Future<void> _initializeInternal() async {
    print('🔔 Initializing NotificationService...');

    // Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Capture launch details so taps from terminated state can be replayed when UI is ready
    await _captureLaunchNotification();

    // Request permissions
    await _requestPermissions();

    // Note: FCMService handles foreground messages to prevent duplicates
    // This service only provides notification display methods

    print('✅ NotificationService initialized');
  }

  // ========================================
  // CRITICAL: Show notification from FCM data
  // ========================================
  static Future<void> showNotificationFromData(
      Map<String, dynamic> data) async {
    // Generate a unique ID for this message
    final String messageId =
        data['message_id'] ?? DateTime.now().toIso8601String();

    // Skip if this is a duplicate message
    if (_processedMessageIds.contains(messageId)) {
      print('🚫 Duplicate message detected, skipping notification');
      return;
    }

    // Add to processed messages
    _processedMessageIds.add(messageId);

    // Clean up after 5 minutes to prevent memory leaks
    Future.delayed(Duration(minutes: 5), () {
      _processedMessageIds.remove(messageId);
    });
    try {
      print('🔔 Creating notification from data: $data');

      final title = data['title'] ?? 'New Message';
      final body = data['body'] ?? 'You have a new message';

      print('📱 Notification: $title - $body');

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'chat_channel',
        'Chat Messages',
        channelDescription: 'Notifications for chat messages',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        fullScreenIntent: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifications.show(
        notificationId,
        title,
        body,
        details,
        payload: json.encode(data),
      );

      print('✅ Notification shown with ID: $notificationId');
    } catch (e, stackTrace) {
      print('❌ Error showing notification: $e\n$stackTrace');
    }
  }

  static Future<void> _requestPermissions() async {
    print('🔔 Requesting permissions...');

    // FCM permissions
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('📱 FCM Permission status: ${settings.authorizationStatus}');

    // Android notification channel
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Chat channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'chat_channel',
          'Chat Messages',
          description: 'Notifications for chat messages',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Digital HR channel (for scheduled notifications)
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'digital_hr_channel',
          'Digital HR Notifications',
          description: 'Notifications for HR events and reminders',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      print('✅ Android notification channel created: chat_channel');
      print('✅ Android notification channel created: digital_hr_channel');
    }
  }

  static Future<void> _captureLaunchNotification() async {
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      final response = details?.notificationResponse;

      if ((details?.didNotificationLaunchApp ?? false) && response != null) {
        print('📱 Captured launch notification payload for deferred handling');
        _pendingNotificationResponse = response;
        _pendingNotificationHandled = false;
        _launchedFromNotification = true;
      } else {
        _pendingNotificationResponse = null;
        _pendingNotificationHandled = false;
        _launchedFromNotification = false;
      }
    } catch (e) {
      print('❌ Failed to capture launch notification: $e');
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');

    if (response.payload != null) {
      Map<String, dynamic> data = {};
      try {
        data = json.decode(response.payload!);
        print('📱 Processing notification data: $data');
      } catch (e) {
        print('⚠️ Payload is not valid JSON, attempting fallback parse');
        try {
          data = _parsePayloadString(response.payload!);
          print('📱 Fallback parsed data: $data');
        } catch (e) {
          print('❌ Fallback parsing failed: $e');
        }
      }

      try {
        if (data.isNotEmpty && data['type'] == 'chat') {
          print('📱 Navigating to chat screen');
          final conversation = Conversation(
            id: int.parse(data["conversation_id"] ?? "0"),
            name: data["sender_name"] ?? "",
            type: "private",
            participants: [int.parse(data["sender_id"] ?? "0")],
            participantNames: data["sender_name"] ?? "",
          );

          Get.to(() => ChatScreen(conversation: conversation));
        } else if (data.isNotEmpty && (data['type'] == 'group_chat' || data['type'] == 'group_chat_message' || data['type'] == 'project_chat')) {
          print('📱 Navigating to project chat screen');
          _navigateToProjectChat(data);
        } else {
          print('📱 Navigating to notifications screen');
          Get.to(() => NotificationScreen());
        }
      } catch (e) {
        print('❌ Error handling notification tap: $e');
      }
    } else {
      print('❌ No payload in notification tap');
    }
  }

  /// Run pending notification navigation once navigation stack is ready
  static Future<void> processPendingNotificationResponse() async {
    if (_pendingNotificationHandled) return;
    if (_pendingNotificationResponse == null) return;

    _pendingNotificationHandled = true;
    final response = _pendingNotificationResponse!;
    _pendingNotificationResponse = null;

    print('🎯 Processing pending notification response from cold-start');
    _onNotificationTap(response);
  }

  /// Fallback parser for payload strings that are Dart map-like (e.g. "{key: value, key2: value2}")
  static Map<String, dynamic> _parsePayloadString(String payload) {
    final Map<String, dynamic> map = {};

    // Remove surrounding braces if any
    var str = payload.trim();
    if (str.startsWith('{') && str.endsWith('}')) {
      str = str.substring(1, str.length - 1);
    }

    // Match key: value pairs
    final pattern = RegExp(r"(\w+)\s*:\s*([^,]+)(?:,|\z)");
    for (final match in pattern.allMatches(str)) {
      final key = match.group(1)!.trim();
      var val = match.group(2)!.trim();

      // Trim surrounding quotes and whitespace (use hex escapes to avoid quote-delimiter issues)
      val = val.replaceAll(RegExp(r'^[\x27\x22]+|[\x27\x22]+$'), '').trim();

      map[key] = val;
    }

    return map;
  }

  /// Navigate to project chat with full project details
  static Future<void> _navigateToProjectChat(Map<String, dynamic> data) async {
    try {
      print('🎯 INSTANT PROJECT CHAT NAVIGATION');

      // Extract data immediately
      final conversationId = int.tryParse(data['conversation_id']?.toString() ?? '0') ?? 0;
      final projectId = int.tryParse(data['project_id']?.toString() ?? '0') ?? 0;
      final projectName = data['project_name'] ?? data['conversation_name'] ?? data['name'] ?? 'Chat';
      
      print('📊 Data: conversationId=$conversationId, projectId=$projectId, projectName=$projectName');

      // NAVIGATE IMMEDIATELY without waiting for API calls
      if (conversationId > 0 || projectId > 0 || projectName.isNotEmpty) {
        Get.to(
          () => ProjectChatScreen(
            projectId: projectId,
            projectName: projectName,
            leaders: [],
            members: [],
            conversationId: conversationId > 0 ? conversationId : null,
          ),
        );
        print('✅ Navigation completed instantly');
        
        // Load project details in background (fire and forget)
        _loadProjectDetailsInBackground(projectId, projectName, conversationId);
      } else {
        print('❌ Missing required navigation data');
      }
    } catch (e) {
      print('❌ Navigation error: $e');
    }
  }

  /// Load project details in background after navigation (non-blocking)
  static void _loadProjectDetailsInBackground(int projectId, String projectName, int conversationId) {
    // Fire and forget - don't wait for this
    Future<void>.microtask(() async {
      try {
        if (projectId > 0) {
          // Try to load full project details
          final project = await ProjectService.getProjectById(projectId);
          if (project != null) {
            print('✅ Loaded project details in background: ${project.name}');
          }
        } else if (projectName.isNotEmpty) {
          // Try to find project by name
          final project = await ProjectService.findProjectByConversationName(projectName);
          if (project != null) {
            print('✅ Found project by name in background: ${project.name}');
          }
        }
      } catch (e) {
        print('⚠️ Background data loading failed (non-blocking): $e');
      }
    });
  }

  static Future<void> cleanup() async {
    print('🧹 Cleaning up notification service...');

    // Stop listening without removing delivered notifications
    // Clearing subscriptions prevents duplicate listeners when app resumes.
    await _messageSubscription?.cancel();
    _messageSubscription = null;

    // Clear processed IDs so new notifications are not skipped on next init
    _processedMessageIds.clear();
    _isInitialized = false;

    print('✅ Notification service cleaned up (listeners stopped, notifications kept)');
  }
}
