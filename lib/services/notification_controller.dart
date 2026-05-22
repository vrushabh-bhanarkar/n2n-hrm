import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:get/get.dart';
import 'package:cnattendance/screens/chat/project_chat_screen.dart';
import 'package:cnattendance/services/chat/chat_service.dart';
import 'package:cnattendance/services/project_service.dart';
import 'package:cnattendance/services/fcm_service.dart';
import 'package:cnattendance/services/notification_service.dart';

class NotificationController {
  /// Track if this action was triggered by user interaction (not automatic processing)
  static bool _isUserInitiated = false;
  
  /// Track app startup time for safety window
  static DateTime? _appStartTime;
  static const int _STARTUP_SAFETY_WINDOW_MS = 3000; // 3 seconds
  
  /// Initialize startup time (called from main.dart)
  static void initStartupTime() {
    _appStartTime = DateTime.now();
    print('⏰ NotificationController startup safety window activated');
  }
  
  /// Check if we're in startup safety window
  static bool _isInStartupWindow() {
    if (_appStartTime == null) return false;
    
    final elapsed = DateTime.now().difference(_appStartTime!).inMilliseconds;
    final inWindow = elapsed < _STARTUP_SAFETY_WINDOW_MS;
    
    if (inWindow) {
      print('⏰ Still in startup safety window (${elapsed}ms/${_STARTUP_SAFETY_WINDOW_MS}ms) - blocking awesome notification action');
    }
    
    return inWindow;
  }

  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
    print('📳 Notification created: ${receivedNotification.title}');
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    print('📱 Notification displayed: ${receivedNotification.title}');
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    print('🗑️ Notification dismissed: ${receivedAction.title}');
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    try {
      print('👆 Notification tapped: ${receivedAction.title}');
      print('   _isUserInitiated: $_isUserInitiated');
      print('🔗 Payload: ${receivedAction.payload}');

      // Check startup safety window FIRST
      if (_isInStartupWindow()) {
        print('❌ BLOCKING: Still in startup safety window - ignoring awesome notification action');
        return;
      }

      // Only process if triggered by user interaction (not automatic cold-start processing)
      if (!_isUserInitiated) {
        print('❌ Skipping action processing - not user initiated (likely automatic awesome_notifications callback)');
        return;
      }

      final payload = receivedAction.payload;
      if (payload == null) {
        print('❌ No payload found in notification');
        return;
      }

      // Handle different types of chat notifications
      await _handleChatNotificationClick(payload);
    } catch (e) {
      print('❌ Error handling notification action: $e');
    }
  }

  /// Public method to handle chat notifications from payload (used by LocalNotificationService)
  static Future<void> handleChatNotificationFromPayload(Map<String, String?> payload) async {
    await _handleChatNotificationClick(payload);
  }

  /// Handle chat notification clicks and navigate to appropriate screens
  static Future<void> _handleChatNotificationClick(Map<String, String?> payload) async {
    try {
      print('🚀 Processing chat notification click...');

      // Extract conversation ID from different payload formats
      String? conversationId;
      String? messageId;
      String? projectName;

      // Check for different payload patterns
      for (final key in payload.keys) {
        final value = payload[key];
        if (value == null) continue;

        print('🔍 Payload key: $key, value: $value');

        // Handle polling chat payload: 'polling_chat_22_106'
        if (value.startsWith('polling_chat_')) {
          final parts = value.split('_');
          if (parts.length >= 3) {
            conversationId = parts[2]; // Extract conversation ID
            if (parts.length >= 4) {
              messageId = parts[3]; // Extract message ID
            }
          }
        }
        // Handle global chat payload: 'global_chat_22_106'
        else if (value.startsWith('global_chat_')) {
          final parts = value.split('_');
          if (parts.length >= 3) {
            conversationId = parts[2]; // Extract conversation ID
            if (parts.length >= 4) {
              messageId = parts[3]; // Extract message ID
            }
          }
        }
        // Handle FCM payload format
        else if (key == 'conversation_id') {
          conversationId = value;
        }
        else if (key == 'project_name') {
          projectName = value;
        }
      }

      if (conversationId != null) {
        print('✅ Found conversation ID: $conversationId');
        await _navigateToProjectChat(conversationId, projectName ?? '');
      } else {
        print('❌ Could not extract conversation ID from payload');
        // Fallback: try to extract from any string value
        for (final value in payload.values) {
          if (value != null && value.contains('chat_')) {
            print('🔄 Attempting fallback extraction from: $value');
            final match = RegExp(r'chat_(\d+)').firstMatch(value);
            if (match != null) {
              conversationId = match.group(1);
              print('✅ Fallback extraction successful: $conversationId');
              await _navigateToProjectChat(conversationId!, projectName ?? '');
              return;
            }
          }
        }
        print('❌ All extraction methods failed');
      }
    } catch (e) {
      print('❌ Error processing chat notification: $e');
    }
  }

  /// Navigate to project chat screen for the given conversation
  static Future<void> _navigateToProjectChat(String conversationId, String? projectName) async {
    try {
      print('🧭 Navigating to conversation $conversationId...');

      // Get conversation details to find the associated project
      final conversations = await ChatService.getConversations();
      final conversation = conversations.firstWhere(
        (conv) => conv.id.toString() == conversationId,
        orElse: () => throw Exception('Conversation not found'),
      );

      print('📝 Found conversation: ${conversation.name}');

      // Use ProjectService to find the actual project details
      final project = await ProjectService.findProjectByConversationName(conversation.name);
      
      if (project == null) {
        throw Exception('Could not find project for conversation: ${conversation.name}');
      }
      
      print('🎯 Navigating to ProjectChatScreen...');
      print('📊 Project: ${project.name} (ID: ${project.id})');

      // Navigate to the project chat screen with proper project data
      Get.to(() => ProjectChatScreen(
        projectId: project.id,
        projectName: project.name,
        leaders: project.leaders,
        members: project.members,
      ));

      print('✅ Navigation completed successfully');
    } catch (e) {
      print('❌ Error navigating to project chat: $e');
      
      // Fallback: Navigate to a generic chat screen or show an error
      Get.snackbar(
        'Navigation Error',
        'Could not open the chat. Please try opening it from the app.',
        duration: Duration(seconds: 3),
      );
    }
  }

  /// Extract project name from conversation name
  static String _extractProjectNameFromConversation(String conversationName) {
    // Remove common suffixes like "Team Chat"
    return conversationName
        .replaceAll(' Team Chat', '')
        .replaceAll(' Chat', '')
        .trim();
  }

  /// Enable processing of awesome_notifications actions
  /// Call this after the app UI is fully loaded and user can interact
  static void enableAwesomeNotificationsProcessing() {
    print('📱 Enabling awesome_notifications action processing');
    _isUserInitiated = true;
  }

  /// Disable processing of awesome_notifications actions  
  /// Call this during cold-start to prevent automatic navigation
  static void disableAwesomeNotificationsProcessing() {
    print('📱 Disabling awesome_notifications action processing');
    _isUserInitiated = false;
  }
}