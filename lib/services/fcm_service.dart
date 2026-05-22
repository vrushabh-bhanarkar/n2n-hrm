import 'package:cnattendance/screen/profile/NotificationScreen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'local_notification_service.dart';
import 'package:get/get.dart';
import 'package:cnattendance/screen/profile/chatscreen.dart' hide ChatScreen;
import 'package:cnattendance/screens/chat/chat_screen.dart';
import 'package:cnattendance/screens/chat/project_chat_screen.dart';
// Removed backend service imports to operate without remote backend
import 'package:cnattendance/model/chat/conversation.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/navigationservice.dart';

/// Global variables to track current chat context and message deduplication
String? _currentChatConversationId;
bool _isInChatScreen = false;
RemoteMessage? _pendingInitialMessage;
bool _pendingInitialMessageHandled = false;
bool _launchedFromNotification = false;

/// CRITICAL: Must be top-level function for background handling
@pragma('vm:entry-point')
Future<void> fcmBackgroundMessageHandler(RemoteMessage message) async {
  print('🔥🔥🔥 BACKGROUND HANDLER CALLED 🔥🔥🔥');
  print('📱 Message: ${message.notification?.title ?? message.data['title']}');
  print('� Has notification payload: ${message.notification != null}');
  print('📱 Data: ${message.data}');

  // Initialize Firebase in background only if not already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
    print('✅ Firebase initialized in background handler');
  }

  // IMPORTANT: If the message has a 'notification' field, FCM already displayed it
  // We only need to show a custom notification if it's a data-only message
  if (message.notification != null) {
    print('✅ Native notification already shown by FCM');
    // FCM has already displayed the notification in the system tray
    // We just need to handle any additional processing here if needed
    return;
  }

  // Only show custom notification if it's a data-only message
  print('⚠️ Data-only message - creating custom notification');
  await _showBackgroundNotificationDirect(message.data);

  print('✅ Background notification processed');
}

/// Direct notification method for background context (when app is killed)
Future<void> _showBackgroundNotificationDirect(
    Map<String, dynamic> data) async {
  try {
    print('🔔 Creating background notification directly from data: $data');

    // Import flutter_local_notifications directly for background use
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    // Initialize with minimal settings for background context
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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

    await notifications.initialize(settings);

    // Create notification channel for Android
    if (Platform.isAndroid) {
      final androidPlugin = notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

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
    }

    final title = data['title'] ?? 'New Message';
    final body = data['body'] ?? 'You have a new message';

    print('📱 Background Notification: $title - $body');

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
      category: AndroidNotificationCategory.message,
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

    await notifications.show(
      notificationId,
      title,
      body,
      details,
      // Encode as JSON so it can be parsed on app resume
      payload: json.encode(data),
    );

    print('✅ Background notification shown with ID: $notificationId');
  } catch (e, stackTrace) {
    print('❌ Error showing background notification: $e\n$stackTrace');
  }
}

/// Firebase Cloud Messaging service for handling push notifications
class FCMService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static AppLifecycleState _lastKnownState = AppLifecycleState.resumed;
  static bool _isInitialized = false;
  static bool _observerRegistered = false;
  static Future<void>? _initializeFuture;
  static final _AppLifecycleObserver _appLifecycleObserver =
      _AppLifecycleObserver();

  /// Initialize FCM and request permissions
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
    try {
      // Track app lifecycle for better background detection
      if (!_observerRegistered) {
        WidgetsBinding.instance.addObserver(_appLifecycleObserver);
        _observerRegistered = true;
      }

      // IMPORTANT: Enable native system notifications for BOTH platforms
      // This allows FCM to show native notifications in the system tray
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true, // Show native notification banners
        badge: true, // Update badge
        sound: true, // Play notification sound
      );
      print(
          '✅ Native FCM notifications enabled - notifications will show in system tray');

      // Request notification permissions
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('FCM Permission granted: ${settings.authorizationStatus}');

      // Verify notification permissions are properly set
      await _verifyNotificationPermissions();

      // For iOS, ensure APNS token is available before getting FCM token
      if (Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          print('⚠️ APNS token not available yet, waiting...');
          await Future.delayed(Duration(seconds: 1));
          apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            print('✅ APNS token obtained');
          } else {
            print('⚠️ APNS token still not available, will retry on login');
          }
        }
      }

      // Get the FCM token
      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      // Handle foreground messages - ONLY for suppressing in active chat, not for showing custom notifications
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap when app is terminated
      // Only navigate if user is already authenticated to avoid redirect after first login
      // Always capture initial message (no backend dependency)
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('📌 Storing initial notification for post-build handling (no backend)');
        _pendingInitialMessage = initialMessage;
        _pendingInitialMessageHandled = false;
        _launchedFromNotification = true;
      } else {
        _pendingInitialMessage = null;
        _pendingInitialMessageHandled = false;
        _launchedFromNotification = false;
      }

      print('✅ FCM initialized successfully');

      // Run diagnostics to help debug notification issues
      await diagnoseNotificationIssues();
    } catch (e) {
      print('❌ FCM initialization error: $e');
      rethrow;
    }
  }

  /// Verify notification permissions are enabled
  static Future<void> _verifyNotificationPermissions() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      print('🔍 Notification Permission Check:');
      print('  - Authorization Status: ${settings.authorizationStatus}');
      print('  - Alert: ${settings.alert}');
      print('  - Badge: ${settings.badge}');
      print('  - Sound: ${settings.sound}');
      print('  - Announcement: ${settings.announcement}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print(
            '⚠️ WARNING: Notifications not authorized! User needs to enable them in settings.');
      } else {
        print('✅ Notifications are properly authorized');
      }
    } catch (e) {
      print('❌ Error verifying permissions: $e');
    }
  }

  /// Handle foreground messages - Shows notifications for both notification and data-only messages
  static void _handleForegroundMessage(RemoteMessage message) async {
    print('📱📱📱 FCM MESSAGE RECEIVED IN FOREGROUND 📱📱📱');
    print('📱 Title: ${message.notification?.title}');
    print('📱 Body: ${message.notification?.body}');
    print('📱 Has notification payload: ${message.notification != null}');
    print('📱 Has data: ${message.data.isNotEmpty}');
    print('📱 Full message data: ${message.data}');
    print('📱 Message ID: ${message.messageId}');
    print('📱 App State: ${WidgetsBinding.instance.lifecycleState}');

    String? messageConversationId = message.data['conversation_id'];
    print('📱 Message conversation ID: $messageConversationId');

    // Check if user is in the same chat conversation
    if (_isInChatScreen &&
        messageConversationId != null &&
        _currentChatConversationId == messageConversationId.toString()) {
      print('🚫 User is viewing this chat - suppressing notification');
      return; // Don't show notification if user is already in this chat
    }

    // CRITICAL: FCM only shows notifications automatically when app is in BACKGROUND
    // When app is in FOREGROUND, we must manually show the notification
    // Show notification for all messages (both notification and data-only)
    print('📱 App is in foreground - manually showing notification');

    String title;
    String body;

    if (message.notification != null) {
      // Extract from notification field
      title =
          message.notification!.title ?? message.data['title'] ?? 'New Message';
      body = message.notification!.body ??
          message.data['body'] ??
          'You have a new message';
      print('📱 Using notification field: $title - $body');
    } else {
      // Extract from data field (data-only message)
      title = message.data['title'] ?? 'New Message';
      body = message.data['body'] ?? 'You have a new message';
      print('📱 Using data field: $title - $body');
    }

    // Show the notification
    await _showForegroundNotification(title, body, message.data);
  }

  /// Show notification when app is in foreground
  /// CRITICAL: FCM only auto-shows notifications in background, we must manually show in foreground
  static Future<void> _showForegroundNotification(
      String title, String body, Map<String, dynamic> data) async {
    try {
      print('🔔 Showing foreground notification: $title - $body');

      // Initialize local notification service
      await LocalNotificationService.initialize();

      // Show notification with properly encoded JSON payload
      await LocalNotificationService.showBackgroundNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: json.encode(data), // Properly encode as JSON
      );

      print('✅ Foreground notification displayed successfully');
    } catch (e, stackTrace) {
      print('❌ Failed to show foreground notification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Handle notification tap
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    final navigationStartTime = DateTime.now();

    // Fast path: check for chat types first (most common)
    final rawType = (message.data['type'] ?? message.data['action'] ?? '')
        .toString()
        .toLowerCase();

    if (rawType.contains('chat') ||
        rawType.contains('message') ||
        rawType.contains('group')) {
      // Direct chat
      if (rawType.contains('chat') &&
          !rawType.contains('group') &&
          !rawType.contains('project')) {
        _navigateToDirectChat(message.data, navigationStartTime);
        return;
      }
      // Project/group chat
      if (rawType.contains('group') || rawType.contains('project')) {
        await _navigateToProjectChat(message.data, navigationStartTime);
        return;
      }
    }

    // Detailed handling for other notification types
    String type = rawType.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    print('📱 Notification type: $type');

    switch (type) {
      case 'chat':
      case 'message':
        _navigateToDirectChat(message.data, navigationStartTime);
        break;
      case 'project_chat':
      case 'group_chat':
      case 'group_chat_message':
        await _navigateToProjectChat(message.data, navigationStartTime);
        break;
      case 'logout_rejected':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (Get.currentRoute == '/logout-pending')
              Get.back();
            else
              Get.offAllNamed('/dashboard');
          } catch (e) {
            Get.offAllNamed('/dashboard');
          }
        });
        break;
      case 'logout_approved':
        await _handleLogoutApproved();
        break;
      default:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            Get.to(() => NotificationScreen());
            final duration =
                DateTime.now().difference(navigationStartTime).inMilliseconds;
            print('✅ Notification screen: ${duration}ms');
          } catch (e) {
            print('❌ Navigation error: $e');
          }
        });
    }
  }

  /// Handle logout approved notification
  static Future<void> _handleLogoutApproved() async {
    try {
      await Preferences().clearPrefs();
      Get.offAllNamed('/login');
    } catch (e) {
      print('❌ Error handling logout approval: $e');
      Get.offAllNamed('/login');
    }
  }

  /// Navigate to direct chat (1-on-1) - OPTIMIZED FOR SPEED with safe navigation
  /// Creates conversation immediately and navigates without waiting for API calls
  static void _navigateToDirectChat(
      Map<String, dynamic> data, DateTime navigationStartTime) {
    try {
      // Fast path: create Conversation object immediately from notification data
      final conversationId =
          int.tryParse(data['conversation_id']?.toString() ?? '0') ?? 0;
      final senderId = int.tryParse(data['sender_id']?.toString() ?? '0') ?? 0;
      final senderName = data['sender_name'] ?? data['name'] ?? 'Chat';

      if (conversationId <= 0 || senderId <= 0) {
        print('❌ Missing conversation or sender ID');
        return;
      }

      // Create Conversation object immediately with minimal data
      final conversation = Conversation(
        id: conversationId,
        name: senderName,
        type: 'private',
        participants: [senderId],
        participantNames: senderName,
      );

      // SAFE NAVIGATION: Wait for navigator to be ready using postFrameCallback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Use Get.to for compatibility with existing GetX navigation
        Get.to(() => ChatScreen(conversation: conversation));

        final duration =
            DateTime.now().difference(navigationStartTime).inMilliseconds;
        print('✅ Chat navigation: ${duration}ms');
      });
    } catch (e) {
      print('❌ Chat nav error: $e');
    }
  }

  /// Navigate to project/group chat - OPTIMIZED FOR SPEED with safe navigation
  static Future<void> _navigateToProjectChat(
      Map<String, dynamic> data, DateTime navigationStartTime) async {
    try {
      // Fast path: extract essential data only
      final conversationId =
          int.tryParse(data['conversation_id']?.toString() ?? '0') ?? 0;
      final projectId =
          int.tryParse(data['project_id']?.toString() ?? '0') ?? 0;
      final projectName =
          data['project_name'] ?? data['name'] ?? 'Project Chat';

      // SAFE NAVIGATION: Wait for navigator to be ready using postFrameCallback
      if (conversationId > 0 || projectId > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.to(
            () => ProjectChatScreen(
              projectId: projectId,
              projectName: projectName,
              leaders: [],
              members: [],
              conversationId: conversationId > 0 ? conversationId : null,
            ),
          );

          final duration =
              DateTime.now().difference(navigationStartTime).inMilliseconds;
          print('✅ Project chat navigation: ${duration}ms');
        });
      } else {
        print('⚠️ Invalid project/conversation ID');
      }
    } catch (e) {
      print('❌ Project chat nav error: $e');
    }
  }

  /// Set chat screen context - call when entering/leaving chat screens
  static void setChatScreenContext(
      {String? conversationId, bool isInChat = false}) {
    _currentChatConversationId = conversationId;
    _isInChatScreen = isInChat;
    print(
        '📱 Chat context updated - ConversationId: $conversationId, InChat: $isInChat');
  }

  /// Get current chat conversation ID (for polling service)
  static String? getCurrentChatConversationId() {
    return _currentChatConversationId;
  }

  /// Check if user is in chat screen (for polling service)
  static bool isInChatScreen() {
    return _isInChatScreen;
  }

  /// Get the current FCM token
  static Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to project chat notifications
  static Future<void> subscribeToProjectChat(int projectId) async {
    try {
      String topic = 'project_chat_$projectId';
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to project chat: $topic');
    } catch (e) {
      print('❌ Error subscribing to project chat $projectId: $e');
    }
  }

  /// Unsubscribe from project chat notifications
  static Future<void> unsubscribeFromProjectChat(int projectId) async {
    try {
      String topic = 'project_chat_$projectId';
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from project chat: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from project chat $projectId: $e');
    }
  }

  /// Subscribe to all user's conversation notifications
  static Future<void> subscribeToUserChats(int userId) async {
    try {
      String topic = 'user_chats_$userId';
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to user chats: $topic');
    } catch (e) {
      print('❌ Error subscribing to user chats $userId: $e');
    }
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  /// Get current app state for background detection
  static bool get isAppInBackground {
    return _lastKnownState != AppLifecycleState.resumed;
  }

  /// Replay a pending initial message after the navigator is ready
  static Future<void> processInitialMessageIfAny() async {
    if (_pendingInitialMessageHandled) return;
    if (_pendingInitialMessage == null) return;

    _pendingInitialMessageHandled = true;
    final message = _pendingInitialMessage!;
    _pendingInitialMessage = null;

    print('🎯 Processing pending FCM initial message from cold-start');
    final navigationStartTime = DateTime.now();
    await _handleNotificationTap(message);
  }

  /// Update app state
  static void updateAppState(AppLifecycleState state) {
    _lastKnownState = state;
    print('📱 App state changed to: $state');

    // When app goes to background, enable notifications for all chats
    if (state != AppLifecycleState.resumed) {
      print('📱 App backgrounded - enabling background notifications');
    } else {
      print('📱 App resumed - foreground mode');
    }
  }

  /// Force show notification regardless of app state (Flutter-only solution)
  static Future<void> forceShowNotification(RemoteMessage message) async {
    try {
      await LocalNotificationService.initialize();

      // Extract title and body from both sources
      String title =
          message.data['title'] ?? message.notification?.title ?? 'New Message';

      String body = message.data['body'] ??
          message.data['message'] ??
          message.notification?.body ??
          'You have received a new message';

      // Always show notification with maximum priority
      await LocalNotificationService.showBackgroundNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: message.data.toString(),
      );

      print('✅ Forced notification displayed: $title');
    } catch (e) {
      print('❌ Force notification error: $e');
    }
  }

  /// Diagnostic method to check FCM notification configuration
  static Future<void> diagnoseNotificationIssues() async {
    print('\n🔍🔍🔍 FCM NOTIFICATION DIAGNOSTICS 🔍🔍🔍');

    try {
      // Check FCM token
      String? token = await _firebaseMessaging.getToken();
      print('✅ FCM Token: ${token?.substring(0, 30)}...');
      // Check APNS token (iOS only)
      try {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        print('✅ APNS Token: ${apnsToken ?? 'not-set'}');
      } catch (e) {
        print('⚠️ Could not read APNS token: $e');
      }

      // Check notification permissions
      NotificationSettings settings =
          await _firebaseMessaging.getNotificationSettings();
      print('\n📋 Notification Settings:');
      print('  - Authorization: ${settings.authorizationStatus}');
      print('  - Alert: ${settings.alert}');
      print('  - Badge: ${settings.badge}');
      print('  - Sound: ${settings.sound}');
      print('  - Announcement: ${settings.announcement}');
      print('  - CarPlay: ${settings.carPlay}');
      print('  - CriticalAlert: ${settings.criticalAlert}');
      print('  - LockScreen: ${settings.lockScreen}');
      print('  - NotificationCenter: ${settings.notificationCenter}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('\n❌ PROBLEM: Notifications NOT authorized!');
        print('   Solution: User must enable notifications in device settings');
      } else {
        print('\n✅ Notifications are authorized');
      }

      // Check Android notification channel
      if (Platform.isAndroid) {
        print('\n📱 Android Configuration:');
        print('  - Default channel: chat_channel (set in AndroidManifest.xml)');
        print('  - FCM messages should include a "notification" field for native display');
        print('  - For custom channels include android.notification.channel_id');
      }

      // Check app state
      print('\n📲 App State:');
      print('  - Current state: ${WidgetsBinding.instance.lifecycleState}');
      print('  - In chat screen: $_isInChatScreen');

      print('\n✅ Diagnostic complete - check above for any issues\n');
    } catch (e) {
      print('❌ Diagnostic error: $e');
    }
  }
}

/// App lifecycle observer for better background detection
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    FCMService.updateAppState(state);
  }
}
