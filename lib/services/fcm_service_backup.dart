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
import 'package:cnattendance/model/chat/conversation.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';

/// Global variables to track current chat context
String? _currentChatConversationId;
bool _isInChatScreen = false;
RemoteMessage? _pendingInitialMessage;
bool _pendingInitialMessageHandled = false;
bool _launchedFromNotification = false;

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> fcmBackgroundMessageHandler(RemoteMessage message) async {
  print('🔥🔥🔥 BACKGROUND HANDLER CALLED 🔥🔥🔥');
  print('📱 Message: ${message.notification?.title ?? message.data['title']}');
  print('📱 Has notification payload: ${message.notification != null}');
  print('📱 Data: ${message.data}');

  // Initialize Firebase in background only if not already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
    print('✅ Firebase initialized in background handler');
  }

  // If the message has a 'notification' field, FCM already displayed it natively.
  // Only create a custom notification for data-only messages.
  if (message.notification != null) {
    print('✅ Native notification already shown by FCM');
    return;
  }

  print('⚠️ Data-only message - creating custom notification');
  await _showBackgroundNotificationDirect(message.data);
  print('✅ Background notification processed');
}

/// Direct notification method for background context (when app is killed)
Future<void> _showBackgroundNotificationDirect(
    Map<String, dynamic> data) async {
  try {
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

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

  /// Initialize FCM and request permissions
  static Future<void> initialize() async {
    try {
      // Track app lifecycle for better background detection
      WidgetsBinding.instance.addObserver(_AppLifecycleObserver());

      // Enable native system notifications for both platforms (iOS foreground banners)
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      print('✅ Native FCM notifications enabled');

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

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap when app is terminated (cold-start)
      // Store it for deferred processing after navigator is ready
      RemoteMessage? initialMessage =
          await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('📌 Storing initial notification for post-build handling');
        _pendingInitialMessage = initialMessage;
        _pendingInitialMessageHandled = false;
        _launchedFromNotification = true;
      } else {
        _pendingInitialMessage = null;
        _pendingInitialMessageHandled = false;
        _launchedFromNotification = false;
      }

      print('✅ FCM initialized successfully');

      await diagnoseNotificationIssues();
    } catch (e) {
      print('❌ FCM initialization error: $e');
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

  /// Handle foreground messages - shows notifications and suppresses duplicates for active chats
  static void _handleForegroundMessage(RemoteMessage message) async {
    print('📱📱📱 FCM MESSAGE RECEIVED IN FOREGROUND 📱📱📱');
    print('📱 Title: ${message.notification?.title}');
    print('📱 Body: ${message.notification?.body}');
    print('📱 Has notification payload: ${message.notification != null}');
    print('📱 Has data: ${message.data.isNotEmpty}');
    print('📱 Message ID: ${message.messageId}');
    print('📱 App State: ${WidgetsBinding.instance.lifecycleState}');

    String? messageConversationId = message.data['conversation_id'];

    // Suppress notification if user is already viewing this chat conversation
    if (_isInChatScreen &&
        messageConversationId != null &&
        _currentChatConversationId == messageConversationId.toString()) {
      print('🚫 User is viewing this chat - suppressing notification');
      return;
    }

    // FCM only auto-shows notifications in background; in foreground we must show manually
    print('📱 App is in foreground - manually showing notification');

    String title;
    String body;

    if (message.notification != null) {
      title =
          message.notification!.title ?? message.data['title'] ?? 'New Message';
      body = message.notification!.body ??
          message.data['body'] ??
          'You have a new message';
    } else {
      title = message.data['title'] ?? 'New Message';
      body = message.data['body'] ?? 'You have a new message';
    }

    await _showForegroundNotification(title, body, message.data);
  }

  /// Show notification when app is in foreground
  static Future<void> _showForegroundNotification(
      String title, String body, Map<String, dynamic> data) async {
    try {
      await LocalNotificationService.initialize();

      await LocalNotificationService.showBackgroundNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: json.encode(data),
      );

      print('✅ Foreground notification displayed successfully');
    } catch (e, stackTrace) {
      print('❌ Failed to show foreground notification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Handle notification tap - navigate to correct screen based on type
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    final navigationStartTime = DateTime.now();

    final rawType = (message.data['type'] ?? message.data['action'] ?? '')
        .toString()
        .toLowerCase();

    // Fast path for chat-related notifications (most common)
    if (rawType.contains('chat') ||
        rawType.contains('message') ||
        rawType.contains('group')) {
      if (rawType.contains('chat') &&
          !rawType.contains('group') &&
          !rawType.contains('project')) {
        _navigateToDirectChat(message.data, navigationStartTime);
        return;
      }
      if (rawType.contains('group') || rawType.contains('project')) {
        await _navigateToProjectChat(message.data, navigationStartTime);
        return;
      }
    }

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
      case 'announcement':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            Get.to(() => NotificationScreen());
          } catch (e) {
            print('❌ Navigation error: $e');
          }
        });
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

  /// Navigate to direct chat (1-on-1) with safe post-frame callback
  static void _navigateToDirectChat(
      Map<String, dynamic> data, DateTime navigationStartTime) {
    try {
      final conversationId =
          int.tryParse(data['conversation_id']?.toString() ?? '0') ?? 0;
      final senderId = int.tryParse(data['sender_id']?.toString() ?? '0') ?? 0;
      final senderName = data['sender_name'] ?? data['name'] ?? 'Chat';

      if (conversationId <= 0 || senderId <= 0) {
        print('❌ Missing conversation or sender ID');
        return;
      }

      final conversation = Conversation(
        id: conversationId,
        name: senderName,
        type: 'private',
        participants: [senderId],
        participantNames: senderName,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.to(() => ChatScreen(conversation: conversation));
        final duration =
            DateTime.now().difference(navigationStartTime).inMilliseconds;
        print('✅ Chat navigation: ${duration}ms');
      });
    } catch (e) {
      print('❌ Chat nav error: $e');
    }
  }

  /// Navigate to project/group chat with safe post-frame callback
  static Future<void> _navigateToProjectChat(
      Map<String, dynamic> data, DateTime navigationStartTime) async {
    try {
      final conversationId =
          int.tryParse(data['conversation_id']?.toString() ?? '0') ?? 0;
      final projectId =
          int.tryParse(data['project_id']?.toString() ?? '0') ?? 0;
      final projectName =
          data['project_name'] ?? data['name'] ?? 'Project Chat';

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

    if (state != AppLifecycleState.resumed) {
      print('📱 App backgrounded - enabling background notifications');
    } else {
      print('📱 App resumed - foreground mode');
    }
  }

  /// Force show notification regardless of app state
  static Future<void> forceShowNotification(RemoteMessage message) async {
    try {
      await LocalNotificationService.initialize();

      String title =
          message.data['title'] ?? message.notification?.title ?? 'New Message';

      String body = message.data['body'] ??
          message.data['message'] ??
          message.notification?.body ??
          'You have received a new message';

      await LocalNotificationService.showBackgroundNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: json.encode(message.data),
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
      String? token = await _firebaseMessaging.getToken();
      print('✅ FCM Token: ${token?.substring(0, 30)}...');

      try {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        print('✅ APNS Token: ${apnsToken ?? 'not-set'}');
      } catch (e) {
        print('⚠️ Could not read APNS token: $e');
      }

      NotificationSettings settings =
          await _firebaseMessaging.getNotificationSettings();
      print('\n📋 Notification Settings:');
      print('  - Authorization: ${settings.authorizationStatus}');
      print('  - Alert: ${settings.alert}');
      print('  - Badge: ${settings.badge}');
      print('  - Sound: ${settings.sound}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('\n❌ PROBLEM: Notifications NOT authorized!');
        print('   Solution: User must enable notifications in device settings');
      } else {
        print('\n✅ Notifications are authorized');
      }

      if (Platform.isAndroid) {
        print('\n📱 Android Configuration:');
        print(
            '  - Default channel: chat_channel (set in AndroidManifest.xml)');
        print(
            '  - FCM messages should include a "notification" field for native display');
      }

      print('\n📲 App State:');
      print('  - Current state: ${WidgetsBinding.instance.lifecycleState}');
      print('  - In chat screen: $_isInChatScreen');

      print('\n✅ Diagnostic complete\n');
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