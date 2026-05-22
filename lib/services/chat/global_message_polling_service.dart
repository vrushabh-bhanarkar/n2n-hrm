import 'dart:async';
import 'package:cnattendance/model/chat/message.dart';
import 'package:cnattendance/model/chat/conversation.dart';
import 'package:cnattendance/services/chat/chat_service.dart';
import 'package:cnattendance/services/local_notification_service.dart';
import 'package:cnattendance/services/fcm_service.dart';
import 'package:cnattendance/services/whatsapp_notification_service.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';

class GlobalMessagePollingService {
  static final GlobalMessagePollingService _instance = GlobalMessagePollingService._internal();
  factory GlobalMessagePollingService() => _instance;
  GlobalMessagePollingService._internal();

  Timer? _timer;
  Map<int, List<Message>> _lastMessagesPerConversation = {};
  int? _currentUserId;
  bool _isPolling = false;

  /// Start global background polling for all conversations
  void startBackgroundPolling({Duration interval = const Duration(seconds: 10)}) {
    if (_isPolling) {
      print('🔄 Global polling already running');
      return;
    }

    print('🌐 Starting global background message polling...');
    _isPolling = true;

    _timer = Timer.periodic(interval, (timer) {
      _pollAllConversations();
    });

    // Initial check
    _pollAllConversations();
  }

  /// Stop global polling
  void stopBackgroundPolling() {
    if (!_isPolling) return;

    print('🛑 Stopping global background message polling');
    _timer?.cancel();
    _timer = null;
    _isPolling = false;
  }

  /// Check all conversations for new messages
  Future<void> _pollAllConversations() async {
    try {
      // Get current user ID if not cached
      if (_currentUserId == null) {
        final prefs = Preferences();
        _currentUserId = await prefs.getUserId();
      }

      // Get all conversations
      final conversations = await ChatService.getConversations();
      print('🔍 Polling ${conversations.length} conversations for new messages');

      for (final conversation in conversations) {
        await _checkConversationForNewMessages(conversation);
      }
    } catch (e) {
      print('❌ Global polling error: $e');
    }
  }

  /// Check specific conversation for new messages
  Future<void> _checkConversationForNewMessages(Conversation conversation) async {
    try {
      final conversationId = conversation.id;
      final messages = await ChatService.getMessages(conversationId);

      // Get last known messages for this conversation
      final lastMessages = _lastMessagesPerConversation[conversationId] ?? [];

      if (messages.isNotEmpty && lastMessages.isNotEmpty) {
        // Find new messages
        final newMessages = messages.where((message) {
          return !lastMessages.any((lastMessage) => lastMessage.id == message.id);
        }).toList();

        if (newMessages.isNotEmpty) {
          print('📨 Found ${newMessages.length} new messages in conversation ${conversationId} (${conversation.name})');
          await _showNotificationsForNewMessages(newMessages, conversation);
        }
      }

      // Update last messages for this conversation
      _lastMessagesPerConversation[conversationId] = List.from(messages);
    } catch (e) {
      print('❌ Error checking conversation ${conversation.id}: $e');
    }
  }

  /// Show notifications for new messages, respecting chat context
  Future<void> _showNotificationsForNewMessages(
    List<Message> newMessages, 
    Conversation conversation
  ) async {
    try {
      for (final message in newMessages) {
        // Skip own messages
        if (message.senderId == _currentUserId) {
          print('⏩ Skipping own message ${message.id}');
          continue;
        }

        // Check if user is actively in this chat using FCM service
        if (!_shouldShowNotificationForConversation(conversation.id)) {
          print('🚫 User actively in chat ${conversation.id} - suppressing notification');
          continue;
        }

        // Show WhatsApp-style notification for new message
        final senderName = message.sender.name;
        final conversationName = conversation.name;

        try {
          await WhatsAppNotificationService.showMessageNotification(
            title: conversationName,
            body: '$senderName: ${message.message}',
            conversationId: conversation.id.toString(),
            messageId: message.id.toString(),
            messageType: conversation.name.contains('Team Chat') ? 'project_message' : 'group_message',
            additionalData: {
              'sender_name': senderName,
              'conversation_name': conversationName,
            },
          );
          print('✅ WhatsApp-style global notification sent for message ${message.id} in ${conversationName}');
        } catch (e) {
          print('❌ WhatsApp notification failed, trying fallback: $e');
          
          // Fallback to original notification service
          try {
            await LocalNotificationService.showBackgroundNotification(
              id: message.id + 50000, // Unique ID for global polling notifications
              title: conversationName,
              body: '$senderName: ${message.message}',
              payload: 'global_chat_${conversation.id}_${message.id}',
            );
            print('✅ Fallback global notification sent');
          } catch (e2) {
            print('❌ All notification methods failed: $e2');
          }
        }
      }
    } catch (e) {
      print('❌ Error showing global notifications: $e');
    }
  }

  /// Check if notification should be shown for this conversation
  bool _shouldShowNotificationForConversation(int conversationId) {
    // Use FCM service static methods to check if user is actively in this chat
    
    // If no chat context is set, or it's a different conversation, show notification
    if (!FCMService.isInChatScreen()) {
      return true; // User not in any chat screen
    }

    final currentChatId = FCMService.getCurrentChatConversationId();
    if (currentChatId == null) {
      return true; // No specific chat context
    }

    // Don't show notification if user is actively in this conversation
    return currentChatId != conversationId.toString();
  }

  /// Initialize the service with conversation cache
  Future<void> initializeConversationCache() async {
    try {
      print('🔧 Initializing global polling conversation cache...');
      
      final conversations = await ChatService.getConversations();
      
      for (final conversation in conversations) {
        try {
          final messages = await ChatService.getMessages(conversation.id);
          _lastMessagesPerConversation[conversation.id] = List.from(messages);
          print('✅ Cached ${messages.length} messages for conversation ${conversation.id}');
        } catch (e) {
          print('❌ Failed to cache messages for conversation ${conversation.id}: $e');
        }
      }
      
      print('✅ Global polling cache initialized with ${_lastMessagesPerConversation.length} conversations');
    } catch (e) {
      print('❌ Failed to initialize global polling cache: $e');
    }
  }

  /// Check if service is currently polling
  bool get isPolling => _isPolling;

  /// Clear conversation cache (useful for logout)
  void clearCache() {
    _lastMessagesPerConversation.clear();
    _currentUserId = null;
    print('🧹 Global polling cache cleared');
  }
}