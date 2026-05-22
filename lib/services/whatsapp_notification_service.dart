import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'fcm_service.dart';

/// WhatsApp-like notification service that handles all notification scenarios
/// including foreground, background, and closed app states
class WhatsAppNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🚀 Initializing WhatsApp-like Notification Service...');
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Set up FCM handlers with enhanced logic
      _setupFCMHandlers();
      
      _isInitialized = true;
      print('✅ WhatsApp Notification Service initialized successfully');
    } catch (e) {
      print('❌ WhatsApp Notification Service initialization error: $e');
    }
  }

  /// Initialize local notifications with WhatsApp-style channels
  static Future<void> _initializeLocalNotifications() async {
  // Use the launcher mipmap icon as a reliable fallback across builds
  const androidInitialization = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitialization = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidInitialization,
      iOS: iosInitialization,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create WhatsApp-style notification channels
    await _createWhatsAppChannels();
  }

  /// Create WhatsApp-style notification channels
  static Future<void> _createWhatsAppChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // High priority channel for messages (like WhatsApp)
    const highPriorityChannel = AndroidNotificationChannel(
      'messages_high',
      'Chat Messages',
      description: 'High priority notifications for chat messages',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Medium priority channel for group messages
    const groupChannel = AndroidNotificationChannel(
      'group_messages',
      'Group Messages',
      description: 'Notifications for group chat messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Create channels
    await androidPlugin.createNotificationChannel(highPriorityChannel);
    await androidPlugin.createNotificationChannel(groupChannel);
  }

  /// Set up FCM message handlers
  static void _setupFCMHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Background app opened messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Handle initial message when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageOpenedApp(message);
      }
    });
  }

  /// Handle foreground messages (app is open and visible)
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 WhatsApp Service: Foreground message received');
    print('📱 Title: ${message.notification?.title}');
    print('📱 Data: ${message.data}');

    // Check if user is in the conversation this message belongs to
    final messageConversationId = message.data['conversation_id'];
    final currentConversationId = FCMService.getCurrentChatConversationId();
    final isInSameChat = FCMService.isInChatScreen() && 
                        messageConversationId != null && 
                        currentConversationId == messageConversationId;

    if (isInSameChat) {
      print('🚫 User is viewing this conversation - no notification needed');
      return;
    }

    // Show notification for messages from other conversations
    await _showWhatsAppStyleNotification(message, isBackground: false);
  }

  /// Handle messages when app is opened from notification
  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('📱 WhatsApp Service: App opened from notification');
    print('📱 Message data: ${message.data}');

    // Navigate to the appropriate screen based on message data
    _navigateFromNotification(message.data);
  }

  /// Show WhatsApp-style notification
  static Future<void> _showWhatsAppStyleNotification(
    RemoteMessage message, {
    bool isBackground = false,
  }) async {
    try {
      // Extract message details
      final data = message.data;
      final notification = message.notification;
      
      final title = _extractTitle(data, notification);
      final body = _extractBody(data, notification);
      final conversationId = data['conversation_id'] ?? '';
      final messageType = data['type'] ?? 'message';
      
      // Determine notification channel based on message type
      final channelId = messageType == 'group_message' ? 'group_messages' : 'messages_high';
      
      // Create notification details
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == 'group_messages' ? 'Group Messages' : 'Chat Messages',
        channelDescription: 'Chat notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        // WhatsApp-style features
        autoCancel: true,
        ongoing: false,
        category: AndroidNotificationCategory.message,
        fullScreenIntent: isBackground, // Show as heads-up when backgrounded
        // Visual styling
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate unique notification ID
      final notificationId = _generateNotificationId(conversationId, data['message_id']);

      // Show notification
      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: json.encode({
          ...data,
          'timestamp': DateTime.now().toIso8601String(),
          'notification_source': 'whatsapp_service',
        }),
      );

      print('✅ WhatsApp-style notification shown: $title');
    } catch (e) {
      print('❌ Error showing WhatsApp notification: $e');
    }
  }

  /// Extract title from message data
  static String _extractTitle(Map<String, dynamic> data, RemoteNotification? notification) {
    // Priority: data['title'] > notification.title > fallback
    return data['title']?.toString() ?? 
           data['sender_name']?.toString() ?? 
           notification?.title ?? 
           'New Message';
  }

  /// Extract body from message data
  static String _extractBody(Map<String, dynamic> data, RemoteNotification? notification) {
    // Priority: data['body'] > data['message'] > notification.body > fallback
    return data['body']?.toString() ?? 
           data['message']?.toString() ?? 
           notification?.body ?? 
           'You have a new message';
  }

  /// Generate unique notification ID based on conversation and message
  static int _generateNotificationId(String conversationId, String? messageId) {
    // Create a unique but consistent ID for each message
    final combined = '$conversationId-${messageId ?? DateTime.now().millisecondsSinceEpoch}';
    return combined.hashCode.abs().remainder(2147483647); // Keep within int range
  }

  /// Handle notification tap
  static void _onNotificationTap(NotificationResponse response) {
    try {
      print('📱 WhatsApp Service: Notification tapped');
      
      if (response.payload != null) {
        final data = json.decode(response.payload!) as Map<String, dynamic>;
        _navigateFromNotification(data);
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  /// Navigate from notification data
  static void _navigateFromNotification(Map<String, dynamic> data) {
    try {
      final conversationId = data['conversation_id']?.toString();
      final messageType = data['type']?.toString() ?? 'message';
      
      print('📱 Navigating from notification: $messageType to conversation $conversationId');
      
      if (conversationId == null) {
        print('❌ No conversation ID in notification data');
        return;
      }

      // Handle different message types
      switch (messageType) {
        case 'project_message':
        case 'project_chat':
          _navigateToProjectChat(data);
          break;
        case 'group_message':
        case 'group_chat':
          _navigateToGroupChat(data);
          break;
        case 'message':
        case 'chat':
        default:
          _navigateToDirectChat(data);
          break;
      }
    } catch (e) {
      print('❌ Error navigating from notification: $e');
    }
  }

  /// Navigate to project chat
  static void _navigateToProjectChat(Map<String, dynamic> data) {
    final projectId = data['project_id']?.toString();
    final projectName = data['project_name']?.toString() ?? 'Project Chat';
    
    if (projectId != null) {
      print('📱 Navigate to project chat: $projectId - $projectName');
      // TODO: Implement navigation to ProjectChatScreen
      // Example: Get.to(() => ProjectChatScreen(projectId: int.parse(projectId), projectName: projectName));
    }
  }

  /// Navigate to group chat
  static void _navigateToGroupChat(Map<String, dynamic> data) {
    final conversationId = data['conversation_id']?.toString();
    final groupName = data['group_name']?.toString() ?? 'Group Chat';
    
    if (conversationId != null) {
      print('📱 Navigate to group chat: $conversationId - $groupName');
      // TODO: Implement navigation to GroupChatScreen
      // Example: Get.to(() => GroupChatScreen(conversationId: int.parse(conversationId)));
    }
  }

  /// Navigate to direct chat
  static void _navigateToDirectChat(Map<String, dynamic> data) {
    final conversationId = data['conversation_id']?.toString();
    final contactName = data['sender_name']?.toString() ?? 'Chat';
    
    if (conversationId != null) {
      print('📱 Navigate to direct chat: $conversationId - $contactName');
      // TODO: Implement navigation to ChatScreen
      // Example: Get.to(() => ChatScreen(conversationId: int.parse(conversationId)));
    }
  }

  /// Show notification for new message (called from polling service)
  static Future<void> showMessageNotification({
    required String title,
    required String body,
    required String conversationId,
    String? messageId,
    String messageType = 'message',
    Map<String, dynamic>? additionalData,
  }) async {
    // Create RemoteMessage-like structure
    final messageData = {
      'title': title,
      'body': body,
      'message': body,
      'conversation_id': conversationId,
      'message_id': messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'type': messageType,
      ...?additionalData,
    };

    final fakeMessage = _createRemoteMessageFromData(messageData);
    
    // Check if app is in background
    final isBackground = FCMService.isAppInBackground;
    
    await _showWhatsAppStyleNotification(fakeMessage, isBackground: isBackground);
  }

  /// Create RemoteMessage from data (for polling service compatibility)
  static RemoteMessage _createRemoteMessageFromData(Map<String, dynamic> data) {
    return RemoteMessage(
      data: data,
      notification: RemoteNotification(
        title: data['title']?.toString(),
        body: data['body']?.toString(),
      ),
    );
  }

  /// Clear notifications for a specific conversation
  static Future<void> clearConversationNotifications(String conversationId) async {
    try {
      // Get pending notifications
      final pendingNotifications = await _localNotifications.pendingNotificationRequests();
      
      // Cancel notifications for this conversation
      for (final notification in pendingNotifications) {
        if (notification.payload?.contains('"conversation_id":"$conversationId"') == true) {
          await _localNotifications.cancel(notification.id);
        }
      }
      
      print('📱 Cleared notifications for conversation: $conversationId');
    } catch (e) {
      print('❌ Error clearing conversation notifications: $e');
    }
  }

  /// Clear all chat notifications
  static Future<void> clearAllChatNotifications() async {
    try {
      await _localNotifications.cancelAll();
      print('📱 All chat notifications cleared');
    } catch (e) {
      print('❌ Error clearing all notifications: $e');
    }
  }

  /// Get notification permissions status
  static Future<bool> hasNotificationPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.checkPermissions().then((permissions) =>
          permissions?.isEnabled == true) ?? false;
    }
    return false;
  }
}