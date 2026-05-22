import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/chat.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/local_chat_storage.dart';
import 'package:cnattendance/services/realtime_chat_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:cnattendance/utils/logging_middleware.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class ChatController extends GetxController {
  var host = "".obs;
  var hostUsername = "";
  var hostImage = "";
  var convoId = "";
  final chatController = TextEditingController();
  final scrollController = ScrollController();

  var chatList = <Chat>[].obs;

  Preferences pref = Preferences();
  StreamSubscription? _messagesSubscription;

  @override
  Future<void> onReady() async {
    host.value = Get.arguments["name"];
    hostImage = Get.arguments["avatar"];
    hostUsername = Get.arguments["username"];

    setConversationDetail(hostUsername, await pref.getUsername());

    // Listen to real-time messages
    _startListeningToMessages();

    super.onReady();
  }

  Future<void> loadChatMessages() async {
    try {
      List<Chat> messages = await LocalChatStorage.getMessages(convoId);
      chatList.value = messages;

      Future.delayed(Duration(milliseconds: 500)).then((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 1000),
            curve: Curves.fastOutSlowIn,
          );
        }
      });
    } catch (e) {
      print("Failed to load chat messages: ");
    }
  }

  void setConversationDetail(String user1, String user2) {
    int result = user1.compareTo(user2);
    if (result < 0) {
      convoId = user1 + user2;
    } else if (result > 0) {
      convoId = user2 + user1;
    } else {
      convoId = user1 + user2;
    }

    loadChatMessages();
  }

  void _startListeningToMessages() {
    // Ensure we have a valid conversation ID before starting to listen
    if (convoId.isEmpty) {
      print("Cannot start listening: convoId is empty");
      return;
    }

    _messagesSubscription =
        RealtimeChatService.getMessagesStream(convoId).listen((messages) {
      chatList.value = messages;

      // Auto-scroll to bottom when new messages arrive
      Future.delayed(Duration(milliseconds: 100)).then((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }, onError: (error) {
      print("Error listening to messages: $error");
    });
  }

  Future<void> sendMessage(String message) async {
    chatController.clear();

    // Generate unique message ID
    String messageId = '${convoId}_${DateTime.now().millisecondsSinceEpoch}';

    final chatMessage = Chat(
      messageId, // Unique message ID
      message,
      await pref.getUsername(),
      hostUsername,
      DateTime.now(),
    );

    try {
      // Save to cloud first using conversation ID
      await RealtimeChatService.sendMessage(chatMessage);

      // Also save to local storage for offline access
      bool saved = await LocalChatStorage.saveMessage(chatMessage);
      if (saved) {
        print("Message saved to local storage");
      } else {
        print("Failed to save message to local storage");
      }

      // Send push notification
      try {
        sendPushNotifiation(await pref.getUsername(), message, convoId, "chat",
            "", hostUsername);
      } catch (notificationError) {
        print("Push notification failed: $notificationError");
        // Continue without failing the whole message send
      }
    } catch (e) {
      print("Failed to send message: $e");

      // If cloud save fails, still save locally
      bool saved = await LocalChatStorage.saveMessage(chatMessage);
      if (saved) {
        print("Message saved to local storage only");
        loadChatMessages();
      }
    }
  }

  Future<void> listenChat() async {
    loadChatMessages();
  }

  Future<void> sendPushNotifiation(
      String title,
      String message,
      String converstion_id,
      String type,
      String project_id,
      String username) async {
    Preferences preferences = Preferences();

    // Construct the URL correctly - use MAIN_URL + the constant path
    var uri = Uri.parse(Constant.MAIN_URL + Constant.SEND_PUSH_NOTIFICATION);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };
    var users = <String>[];
    users.add(username);

    print('🌐 POST: $uri');
    print(
        '📤 Body: {title: $title, message: $message, conversation_id: $converstion_id, type: $type, project_id: $project_id, usernames: $users}');

    try {
      final http.Client client = await LoggingMiddleware.create();

      try {
        final response = await client.post(uri, headers: headers, body: {
          "title": title,
          "message": message,
          "conversation_id": converstion_id,
          "type": type,
          "project_id": project_id,
          "usernames": jsonEncode(users),
        });

        final responseData = json.decode(response.body);

        if (response.statusCode == 200) {
          print('✅ Push notification sent successfully');
          print(response.body.toString());
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

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    chatController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
