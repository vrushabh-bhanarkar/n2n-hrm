import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/chat/message.dart';
import 'package:cnattendance/model/member.dart';
import 'package:cnattendance/services/chat/chat_service.dart';
import 'package:cnattendance/services/app_lifecycle_service.dart';
import 'package:http/http.dart' as http;
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cnattendance/utils/logging_middleware.dart';
import 'dart:async';

class GroupChatController extends GetxController {
  var host = "".obs;
  var conversationId = 0; // Change to use conversation ID from API
  final chatController = TextEditingController();
  final scrollController = ScrollController();
  var projectId = 0;

  var chatList = <Message>[].obs; // Use Message model from API
  var isLoading = false.obs;
  var currentUserId = 0;
  var currentUsername = "";

  List<Member> leaders = [];
  List<Member> members = [];

  Preferences pref = Preferences();
  Timer? _pollingTimer;
  
  // Track last known message IDs to detect new messages
  Set<int> _lastKnownMessageIds = <int>{};

  @override
  Future<void> onReady() async {
    host.value = Get.arguments["projectName"];
    conversationId = Get.arguments["conversationId"] ?? 0; // Get conversation ID from arguments
    leaders = Get.arguments["leader"] ?? [];
    members = Get.arguments["member"] ?? [];
    projectId = Get.arguments["projectId"] ?? 0;

    currentUsername = await pref.getUsername();
    // Get current user ID if available
    try {
      currentUserId = await pref.getUserId();
    } catch (e) {
      currentUserId = 0;
    }
    
    // Load initial messages from HTTP API
    await loadMessages();
    
    // Start polling for new messages every 5 seconds
    _startPollingMessages();
    
    super.onReady();
  }

  // Load messages from HTTP API
  Future<void> loadMessages() async {
    if (conversationId <= 0) {
      print("Cannot load messages: conversationId is invalid");
      return;
    }
    
    try {
      isLoading.value = true;
      print('🔄 Loading messages for conversation $conversationId');
      
      final messages = await ChatService.getMessages(conversationId);
      
      // Check for new messages if this is not the first load
      if (_lastKnownMessageIds.isNotEmpty) {
        final newMessages = messages.where((message) {
          return !_lastKnownMessageIds.contains(message.id) && 
                 message.senderId != currentUserId; // Don't notify for own messages
        }).toList();
        
        print('🔍 New messages detected: ${newMessages.length}');
        if (newMessages.isNotEmpty) {
          print('📋 New message IDs: ${newMessages.map((m) => m.id).toList()}');
          print('📋 Current user ID: $currentUserId');
          
          // Show notifications for new messages
          for (final message in newMessages) {
            print('🔔 Processing notification for message ${message.id} from ${message.sender.name}');
            await _showMessageNotification(message);
          }
        }
      } else {
        print('🏁 First load - initializing message tracking');
      }
      
      // Sort messages by creation date to ensure correct order (oldest first, newest last)
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      chatList.value = messages;
      
      // Update the set of known message IDs
      _lastKnownMessageIds = messages.map((message) => message.id).toSet();
      print('📊 Tracking ${_lastKnownMessageIds.length} message IDs: ${_lastKnownMessageIds.take(5).toList()}${_lastKnownMessageIds.length > 5 ? '...' : ''}');
      
      print('📨 Loaded ${messages.length} messages from API (sorted by date)');
      
      // Auto-scroll to bottom
      Future.delayed(Duration(milliseconds: 100)).then((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('❌ Failed to load messages: $e');
      Get.snackbar(
        'Error', 
        'Failed to load messages. Please check your internet connection.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Start polling for new messages
  void _startPollingMessages() {
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (conversationId > 0) {
        loadMessages();
      }
    });
  }

  Future<void> sendMessage(String message) async {
    if (conversationId <= 0) {
      Get.snackbar(
        'Error', 
        'Invalid conversation. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      print('📤 Sending message to conversation $conversationId');
      
      // Send message using HTTP API
      await ChatService.sendGroupMessage(
        conversationId: conversationId,
        message: message,
        type: 'text',
      );

      print('✅ Message sent successfully');

      // Send push notification to other users
      try {
        var users = <int>[];
        for (var member in members) {
          if (member.id != currentUserId) { // Don't send to yourself
            users.add(member.id);
          }
        }
        for (var leader in leaders) {
          if (leader.id != currentUserId) { // Don't send to yourself
            users.add(leader.id);
          }
        }
        
        if (users.isNotEmpty) {
          print('🔔 Preparing to send push notification...');
          print('🔔 Recipients: ${users.length} users - $users');
          print('🔔 Message: $message');
          print('🔔 Project: ${host.value} (ID: $projectId)');
          print('🔔 Conversation: $conversationId');
          
          await sendPushNotification(
            "New message in ${host.value}", 
            message,
            conversationId.toString(), 
            "group_chat", 
            projectId.toString(), 
            users
          );
          print('✅ Push notification sent to ${users.length} users');
        } else {
          print('⚠️ No users to send push notification to');
        }
      } catch (e) {
        print('❌ Push notification failed: $e');
      }

      // Reload messages to get the latest
      await loadMessages();

    } catch (e) {
      print('❌ Failed to send message: $e');
      Get.snackbar(
        'Error', 
        'Failed to send message. Please check your internet connection.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }

    // Clear input
    chatController.clear();
  }

  /// Show notification for received messages
  Future<void> _showMessageNotification(Message message) async {
    try {
      final senderName = message.sender.name;
      final notificationTitle = '💬 ${host.value}';
      final notificationBody = '$senderName: ${message.message}';
      
      // Always show notification to ensure users are notified of new messages
      await AppLifecycleService.forceShowNotification(
        id: message.id,
        title: notificationTitle,
        body: notificationBody,
        payload: 'chat_message_${conversationId}_${message.id}',
      );
      print('🔔 Notification shown for message from $senderName');
    } catch (e) {
      print('❌ Failed to show message notification: $e');
    }
  }

  Future<void> sendPushNotification(
      String title,
      String message,
      String converstion_id,
      String type,
      String project_id,
      List<int> usernames) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(
        await preferences.getAppUrl() + Constant.SEND_PUSH_NOTIFICATION);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    print('🌐 POST: $uri');
    print('📤 Headers: $headers');
    print('📤 Body: {title: $title, message: $message, conversation_id: $converstion_id, type: $type, project_id: $project_id, usernames: $usernames}');

    try {
      final http.Client client = await LoggingMiddleware.create();
      
      try {
        final requestBody = {
          "title": title,
          "message": message,
          "conversation_id": converstion_id,
          "type": type,
          "project_id": project_id,
          "usernames": jsonEncode(usernames),
        };
        
        print('📤 Final request body: $requestBody');
        
        final response = await client.post(uri, headers: headers, body: requestBody);

        print('📥 Push notification response status: ${response.statusCode}');
        print('📥 Push notification response body: ${response.body}');

        final responseData = json.decode(response.body);

        if (response.statusCode == 200) {
          print('✅ Push notification sent successfully');
        } else {
          var errorMessage = responseData['message'];
          print('❌ Push notification failed: $errorMessage');
          throw errorMessage;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Push notification failed: $e');
      // Don't rethrow to avoid breaking the chat functionality
    }
  }

  /// Clear local chat messages for this conversation
  Future<void> clearLocalMessages() async {
    // Clear chat list and reload from server
    chatList.clear();
    await loadMessages();
    
    Get.snackbar(
      'Messages Cleared', 
      'Chat display has been cleared and reloaded from server.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Refresh chat messages
  Future<void> refreshMessages() async {
    print('🔄 Refreshing messages from HTTP API');
    await loadMessages();
  }

  @override
  void onClose() {
    _pollingTimer?.cancel();
    chatController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
