import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:io';

/// Enhanced FCM Service for reliable background notifications
/// This service uses flutter_local_notifications for maximum compatibility
/// when the app is closed or in background
class EnhancedFCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;
  
  /// Initialize the enhanced FCM service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🚀 Initializing Enhanced FCM Service...');
      
      // Initialize local notifications first
      await _initializeLocalNotifications();
      
      // Request FCM permissions
      await _requestPermissions();
      
      // Get and log FCM token
      String? token = await getToken();
      print('📱 FCM Token: $token');
      
      // Set up message handlers
      _setupMessageHandlers();
      
      _isInitialized = true;
      print('✅ Enhanced FCM Service initialized successfully');
      
    } catch (e) {
      print('❌ Enhanced FCM Service initialization failed: $e');
      rethrow;
    }
  }
  
  /// Initialize flutter_local_notifications
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
    
    // Create notification channel for Android
    await _createNotificationChannel();
    
    print('✅ Flutter Local Notifications initialized');
  }
  
  /// Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'digital_hr_channel', // Same as in manifest
      'Digital HR Notifications',
      description: 'Notifications for Digital HR app messages and alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    print('✅ Notification channel created: ${channel.id}');
  }
  
  /// Request FCM permissions
  static Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    print('📱 FCM Permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ FCM permissions granted');
    } else {
      print('⚠️ FCM permissions denied or not determined');
    }
  }
  
  /// Set up message handlers
  static void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Check for initial message (app opened from notification)
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageOpenedApp(message);
      }
    });
  }
  
  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) async {
    print('📱 Foreground message received: ${message.messageId}');
    print('📱 Data: ${message.data}');
    
    // Show notification even when app is in foreground
    await _showLocalNotification(message);
  }
  
  /// Handle message opened app
  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('🎯 Notification tapped - opening app');
    print('📱 Data: ${message.data}');
    
    // Handle navigation based on message data
    _navigateBasedOnMessage(message);
  }
  
  /// Handle notification tap
  static void _handleNotificationTap(NotificationResponse response) {
    print('🎯 Local notification tapped');
    print('📱 Payload: ${response.payload}');
    
    if (response.payload != null) {
      // Parse payload and navigate
      _parsePayloadAndNavigate(response.payload!);
    }
  }
  
  /// Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      // Extract title and body from data payload (server sends data-only)
      String title = message.data['title'] ?? 'N2N HRM';
      String body = message.data['body'] ?? message.data['message'] ?? 'New notification';
      String senderName = message.data['sender_name'] ?? '';
      String conversationId = message.data['conversation_id'] ?? '';
      String messageType = message.data['type'] ?? 'general';
      
      // Create payload for tap handling
      Map<String, String> payload = {
        'type': messageType,
        'conversation_id': conversationId,
        'sender_name': senderName,
        'title': title,
        'body': body,
      };
      
      AndroidNotificationDetails androidPlatformChannelSpecifics = 
          AndroidNotificationDetails(
        'digital_hr_channel',
        'Digital HR Notifications',
        channelDescription: 'Notifications for Digital HR app messages and alerts',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        enableLights: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(body),
        category: AndroidNotificationCategory.message,
        autoCancel: true,
      );
      
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await _localNotifications.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: jsonEncode(payload),
      );
      
      print('✅ Local notification shown: $title');
      
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }
  
  /// Navigate based on message
  static void _navigateBasedOnMessage(RemoteMessage message) {
    String messageType = message.data['type'] ?? 'general';
    
    print('🧭 Navigating for message type: $messageType');
    
    // Add your navigation logic here based on message type
    // Example:
    // String conversationId = message.data['conversation_id'] ?? '';
    // if (messageType == 'chat' && conversationId.isNotEmpty) {
    //   Get.toNamed('/chat', arguments: {'conversationId': conversationId});
    // } else if (messageType == 'meeting') {
    //   Get.toNamed('/meetings');
    // }
  }
  
  /// Parse payload and navigate
  static void _parsePayloadAndNavigate(String payload) {
    try {
      Map<String, dynamic> data = jsonDecode(payload);
      String messageType = data['type'] ?? 'general';
      
      print('🧭 Navigating for payload type: $messageType');
      
      // Add your navigation logic here
      // Similar to _navigateBasedOnMessage but for local notification taps
      // String conversationId = data['conversation_id'] ?? '';
      
    } catch (e) {
      print('❌ Error parsing notification payload: $e');
    }
  }
  
  /// Get FCM token
  static Future<String?> getToken() async {
    try {
      // For iOS, ensure APNS token is available first
      if (Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          print('⚠️ APNS token not available yet, waiting...');
          // Wait a bit and retry
          await Future.delayed(Duration(milliseconds: 500));
          apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            print('✅ APNS token obtained: ${apnsToken.substring(0, 10)}...');
          } else {
            print('⚠️ APNS token still not available');
          }
        }
      }
      
      String? token = await _firebaseMessaging.getToken();
      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }
  
  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic $topic: $e');
    }
  }
  
  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic $topic: $e');
    }
  }
  
  /// Delete FCM token
  static Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      print('✅ FCM token deleted');
    } catch (e) {
      print('❌ Error deleting FCM token: $e');
    }
  }
}

/// Global background message handler function for FCM
/// 🔥 CRITICAL: Must be top-level function for background execution
@pragma('vm:entry-point')
Future<void> enhancedFcmBackgroundHandler(RemoteMessage message) async {
  print('🔥🔥 ENHANCED BACKGROUND HANDLER - APP CLOSED 🔥🔥');
  print('📱 Message ID: ${message.messageId}');
  print('📱 Data: ${message.data}');
  
  try {
    // Initialize flutter_local_notifications for background use
    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    final FlutterLocalNotificationsPlugin localNotifications = 
        FlutterLocalNotificationsPlugin();
    
    await localNotifications.initialize(initializationSettings);
    
    // Extract notification data
    String title = message.data['title'] ?? 'N2N HRM';
    String body = message.data['body'] ?? message.data['message'] ?? 'New notification';
    
    // Show notification with maximum priority for closed app
    AndroidNotificationDetails androidPlatformChannelSpecifics = 
        AndroidNotificationDetails(
      'digital_hr_channel',
      'Digital HR Notifications',
      channelDescription: 'Notifications for Digital HR app messages and alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
      category: AndroidNotificationCategory.message,
      autoCancel: true,
      fullScreenIntent: true, // 🔥 Show full screen for critical notifications
    );
    
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    
    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
    
    print('✅ Background notification displayed: $title');
    
  } catch (e) {
    print('❌ Enhanced background handler error: $e');
  }
}