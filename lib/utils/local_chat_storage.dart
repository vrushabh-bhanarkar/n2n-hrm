import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:cnattendance/model/chat.dart';

/// Local chat storage service to handle messages when Firestore is unavailable
class LocalChatStorage {
  static const String _chatKey = 'local_chat_messages';
  static const int _maxMessages = 100; // Limit stored messages to prevent storage bloat
  
  static final GetStorage _storage = GetStorage();

  /// Save a message to local storage
  static Future<bool> saveMessage(Chat message) async {
    try {
      List<String> messages = await getStoredMessages();
      
      // Convert message to JSON string
      String messageJson = jsonEncode({
        'id': message.id,
        'message': message.message,
        'sender': message.sender,
        'receiver': message.reciever,
        'date': message.dateTime.toIso8601String(),
      });
      
      // Add new message to the beginning (most recent first)
      messages.insert(0, messageJson);
      
      // Limit storage to prevent bloat
      if (messages.length > _maxMessages) {
        messages = messages.take(_maxMessages).toList();
      }
      
      // Save back to storage
      await _storage.write(_chatKey, messages);
      return true;
    } catch (e) {
      print('❌ Failed to save message locally: $e');
      return false;
    }
  }

  /// Get all stored messages for a conversation
  static Future<List<Chat>> getMessages(String conversationId) async {
    try {
      List<String> messages = await getStoredMessages();
      List<Chat> chatMessages = [];
      
      for (String messageJson in messages) {
        try {
          Map<String, dynamic> data = jsonDecode(messageJson);
          
          // Filter by conversation ID
          if (data['id'] == conversationId) {
            chatMessages.add(Chat(
              data['id'],
              data['message'],
              data['sender'],
              data['receiver'],
              DateTime.parse(data['date']),
            ));
          }
        } catch (e) {
          print('⚠️ Failed to parse stored message: $e');
        }
      }
      
      // Return messages in chronological order (oldest first for display)
      return chatMessages.reversed.toList();
    } catch (e) {
      print('❌ Failed to load local messages: $e');
      return [];
    }
  }

  /// Get raw stored messages from storage
  static Future<List<String>> getStoredMessages() async {
    try {
      var stored = _storage.read(_chatKey);
      if (stored is List) {
        return stored.cast<String>();
      }
      return [];
    } catch (e) {
      print('⚠️ Failed to read from storage: $e');
      return [];
    }
  }

  /// Clear all local chat messages
  static Future<void> clearMessages() async {
    try {
      await _storage.remove(_chatKey);
      print('✅ Local chat messages cleared');
    } catch (e) {
      print('❌ Failed to clear local messages: $e');
    }
  }

  /// Get message count for a conversation
  static Future<int> getMessageCount(String conversationId) async {
    try {
      List<Chat> messages = await getMessages(conversationId);
      return messages.length;
    } catch (e) {
      return 0;
    }
  }

  /// Check if local storage is available
  static bool get isAvailable {
    try {
      return _storage.hasData(_chatKey) || true; // GetStorage is generally available
    } catch (e) {
      return false;
    }
  }
}