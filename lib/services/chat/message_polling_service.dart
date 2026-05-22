import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cnattendance/model/chat/message.dart';
import 'package:cnattendance/services/chat/chat_service.dart';
import 'package:cnattendance/services/local_notification_service.dart';
import 'package:cnattendance/services/fcm_service.dart';
import 'package:cnattendance/services/whatsapp_notification_service.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';

class MessagePollingService {
  Timer? _timer;
  final Function(List<Message>) onNewMessages;
  final Function(String) onError;
  List<Message> _lastMessages = [];
  int? _currentUserId;
  String? _projectName;
  int? _conversationId;
  int? _projectId;
  bool _isFetching = false;

  MessagePollingService({
    required this.onNewMessages,
    required this.onError,
    String? projectName,
    int? conversationId,
    int? projectId,
  })  : _projectName = projectName,
        _conversationId = conversationId,
        _projectId = projectId;

  void startPolling(int conversationId,
      {Duration interval = const Duration(seconds: 30)}) {
    stopPolling();
    _conversationId = conversationId;

    _timer = Timer.periodic(interval, (timer) {
      _checkForNewMessages(conversationId);
    });

    _checkForNewMessages(conversationId);
  }

  void startPollingWithoutInitialLoad(int conversationId,
      {Duration interval = const Duration(seconds: 30)}) {
    stopPolling();
    _conversationId = conversationId;

    _timer = Timer.periodic(interval, (timer) {
      _checkForNewMessages(conversationId);
    });
  }

  void setInitialMessages(List<Message> messages) {
    _lastMessages = List.from(messages);
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkForNewMessages(int conversationId) async {
    // Don't poll when the app is backgrounded/inactive
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) return;
    if (_isFetching) return;
    _isFetching = true;
    try {
      final messages = await ChatService.getMessages(conversationId);

      if (_lastMessages.isEmpty && messages.isNotEmpty) {
        _lastMessages = messages;
        onNewMessages(messages);
        return;
      }

      if (messages.isNotEmpty && _lastMessages.isNotEmpty) {
        final newMessages = messages.where((message) {
          return !_lastMessages
              .any((lastMessage) => lastMessage.id == message.id);
        }).toList();

        if (newMessages.isNotEmpty) {
          print(' New messages detected: ${newMessages.length}');
          await _showNotificationsForNewMessages(newMessages);
          onNewMessages(messages);
        }
      }

      _lastMessages = messages;
    } catch (e) {
      onError('Error polling messages: $e');
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _showNotificationsForNewMessages(
      List<Message> newMessages) async {
    try {
      final prefs = Preferences();
      _currentUserId ??= await prefs.getUserId();

      print(' Processing ${newMessages.length} new messages for notifications');
      print(' Current user ID: $_currentUserId');
      print(' Project: ${_projectName ?? 'Project Chat'}');
      print(' Conversation ID: $_conversationId');

      for (final message in newMessages) {
        print(
            ' Message ${message.id} from user ${message.senderId} (${message.sender.name})');

        if (message.senderId != _currentUserId) {
          final senderName = message.sender.name;
          final projectTitle = _projectName ?? 'Project Chat';

          print(' New message from $senderName: "${message.message}"');

          // 🔥 RESPECT FCM CHAT CONTEXT - Don't show notification if user is in this chat
          if (!_shouldShowNotificationForMessage(_conversationId)) {
            print(
                ' 🚫 User is actively in this chat - suppressing polling notification');
            continue; // Skip notification for this message
          }

          print(' ✅ User not in active chat - showing notification');

          // Show WhatsApp-style notification
          try {
            await WhatsAppNotificationService.showMessageNotification(
              title: projectTitle,
              body: '$senderName: ${message.message}',
              conversationId: _conversationId.toString(),
              messageId: message.id.toString(),
              messageType: _projectId != null ? 'project_message' : 'message',
              additionalData: {
                'sender_name': senderName,
                'project_id': _projectId?.toString(),
                'project_name': _projectName,
              },
            );
            print(
                ' ✅ WhatsApp-style notification sent for message ${message.id}');
          } catch (e) {
            print(' ❌ WhatsApp notification failed, trying fallback: $e');

            // Fallback to LocalNotificationService
            try {
              await LocalNotificationService.showBackgroundNotification(
                id: message.id + 40000, // Unique ID for polling notifications
                title: projectTitle,
                body: '$senderName: ${message.message}',
                payload: 'polling_chat_${_conversationId}_${message.id}',
              );
              print(' ✅ Fallback notification sent');
            } catch (e2) {
              print(' ❌ All notification methods failed: $e2');
            }
          }

          print(
              ' All notification methods completed for message ${message.id}');
        } else {
          print(' Skipped notification for own message ${message.id}');
        }
      }

      print(
          ' Completed processing notifications for ${newMessages.length} new messages');
    } catch (e) {
      print(' Error in comprehensive notification system: $e');
      onError('Error showing notifications: $e');
    }
  }

  /// Check if we should show notification for this conversation
  /// Returns false if user is actively in this chat screen
  bool _shouldShowNotificationForMessage(int? conversationId) {
    if (conversationId == null) return true;

    // Use FCMService to check if user is actively in this chat
    // This respects the same logic as FCM notifications
    try {
      // Check if user is in chat screen AND it's the same conversation
      String? currentConvId = FCMService.getCurrentChatConversationId();
      bool isInChatScreen = FCMService.isInChatScreen();

      if (isInChatScreen && currentConvId == conversationId.toString()) {
        return false; // Don't show notification
      }

      return true; // Show notification
    } catch (e) {
      print(' Error checking chat context: $e');
      return true; // Default to showing notification if error
    }
  }

  void dispose() {
    stopPolling();
  }
}
