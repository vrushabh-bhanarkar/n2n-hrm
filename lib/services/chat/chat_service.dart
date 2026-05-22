import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:cnattendance/model/chat/conversation.dart';
import 'package:cnattendance/model/chat/message.dart';
import 'package:cnattendance/model/chat/user.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';

class ApiLogger {
  static void logRequest(String method, String url, Map<String, String>? headers, String? body) {
    print('\n=== API REQUEST ===');
    print('Method: $method');
    print('URL: $url');
    print('Headers: $headers');
    if (body != null) print('Body: $body');
    print('==================\n');
  }

  static void logResponse(String url, int statusCode, String body) {
    print('\n=== API RESPONSE ===');
    print('URL: $url');
    print('Status Code: $statusCode');
    print('Response Body: $body');
    print('===================\n');
  }

  static void logError(String url, dynamic error) {
    print('\n=== API ERROR ===');
    print('URL: $url');
    print('Error: $error');
    print('=================\n');
  }
}

class ChatService {
  // Get headers for API calls
  static Future<Map<String, String>> getHeaders() async {
    final preferences = Preferences();
    final token = await preferences.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get API base URL - using the main URL from constants with /api suffix
  static String getBaseUrl() {
    return '${Constant.MAIN_URL}/api';
  }

  // Get all conversations
  static Future<List<Conversation>> getConversations() async {
    try {
      final baseUrl = getBaseUrl();
      final url = '$baseUrl/conversations';
      final headers = await getHeaders();
      
      ApiLogger.logRequest('GET', url, headers, null);
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      ApiLogger.logResponse(url, response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true || data['success'] == 1) {
          List<Conversation> conversations = [];
          final dataList = data['data'] as List;
          
          for (int i = 0; i < dataList.length; i++) {
            try {
              final conversation = Conversation.fromJson(dataList[i]);
              conversations.add(conversation);
            } catch (e) {
              print('❌ Error parsing conversation at index $i: $e');
              print('📄 Conversation data: ${dataList[i]}');
              // Continue with other conversations instead of failing completely
            }
          }
          
          return conversations;
        }
      }
      throw Exception('Failed to load conversations: ${response.body}');
    } catch (e) {
      ApiLogger.logError('getConversations', e);
      throw Exception('Network error: $e');
    }
  }

  // Get messages for conversation
  static Future<List<Message>> getMessages(int conversationId, {int page = 1}) async {
    try {
      final baseUrl = getBaseUrl();
      final url = '$baseUrl/messages/$conversationId?per_page=50&page=$page';
      final headers = await getHeaders();
      
      ApiLogger.logRequest('GET', url, headers, null);
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      ApiLogger.logResponse(url, response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true || data['success'] == 1) {
          List<Message> messages = [];
          // Support both paginated { data: { data: [...] } } and flat { data: [...] }
          final rawData = data['data'];
          final List dataList;
          if (rawData is Map && rawData.containsKey('data')) {
            dataList = rawData['data'] as List;
          } else if (rawData is List) {
            dataList = rawData;
          } else {
            dataList = [];
          }
          
          for (int i = 0; i < dataList.length; i++) {
            try {
              final message = Message.fromJson(dataList[i]);
              messages.add(message);
            } catch (e) {
              print('❌ Error parsing message at index $i: $e');
              print('📄 Message data: ${dataList[i]}');
              // Continue with other messages instead of failing completely
            }
          }
          
          return messages;
        }
      }
      throw Exception('Failed to load messages: ${response.body}');
    } catch (e) {
      ApiLogger.logError('getMessages', e);
      throw Exception('Network error: $e');
    }
  }

  // Send message
  static Future<Message> sendMessage({
    int? conversationId,
    int? receiverId,
    required String message,
    String type = 'text',
  }) async {
    try {
      Map<String, dynamic> bodyData = {
        'message': message,
        'type': type,
      };
      
      if (conversationId != null) {
        bodyData['conversation_id'] = conversationId;
      } else if (receiverId != null) {
        bodyData['receiver_id'] = receiverId;
      }
      
      final baseUrl = getBaseUrl();
      final url = '$baseUrl/messages/send';
      final headers = await getHeaders();
      final body = json.encode(bodyData);
      
      ApiLogger.logRequest('POST', url, headers, body);
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      
      ApiLogger.logResponse(url, response.statusCode, response.body);
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success']) {
          return Message.fromJson(data['data']);
        }
      }
      throw Exception('Failed to send message: ${response.body}');
    } catch (e) {
      ApiLogger.logError('sendMessage', e);
      throw Exception('Network error: $e');
    }
  }

  // Send group message
  static Future<Message> sendGroupMessage({
    required int conversationId,
    required String message,
    String type = 'text',
  }) async {
    try {
      final baseUrl = getBaseUrl();
      final url = '$baseUrl/messages/group/send';
      final headers = await getHeaders();
      final body = json.encode({
        'conversation_id': conversationId,
        'message': message,
        'type': type,
      });
      
      ApiLogger.logRequest('POST', url, headers, body);
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      
      ApiLogger.logResponse(url, response.statusCode, response.body);
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success']) {
          return Message.fromJson(data['data']);
        }
      }
      throw Exception('Failed to send group message: ${response.body}');
    } catch (e) {
      ApiLogger.logError('sendGroupMessage', e);
      throw Exception('Network error: $e');
    }
  }

  // Send attachment (image or file)
  static Future<Message> sendAttachment({
    required int conversationId,
    required File file,
    required bool isGroup,
    String message = '',
  }) async {
    try {
      final baseUrl = getBaseUrl();
      // Dedicated backend endpoint for image/document uploads.
      final url = '$baseUrl/messages/upload-attachment';
      final preferences = Preferences();
      final token = await preferences.getToken();

      final ext = file.path.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'heic', 'heif'].contains(ext);
      final mimeType = _mimeFromExt(ext);

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields['conversation_id'] = conversationId.toString();
      // Caption is optional per API contract.
      if (message.trim().isNotEmpty) {
        request.fields['message'] = message.trim();
      }
      request.files.add(await http.MultipartFile.fromPath(
        'attachment',
        file.path,
        contentType: MediaType.parse(mimeType),
      ));

      ApiLogger.logRequest(
        'POST (multipart)',
        url,
        null,
        'file=${file.path}, inferredType=${isImage ? 'image' : 'file'}, conversation_id=$conversationId, isGroup=$isGroup',
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      ApiLogger.logResponse(url, response.statusCode, response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is Map<String, dynamic>) {
          return Message.fromJson(data['data']);
        }
      }
      throw Exception('Failed to send attachment: ${response.body}');
    } catch (e) {
      ApiLogger.logError('sendAttachment', e);
      throw Exception('Network error: $e');
    }
  }

  static String _mimeFromExt(String ext) {
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
      'heic': 'image/heic',
      'heif': 'image/heif',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
      'zip': 'application/zip',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // Delete conversation
  static Future<bool> deleteConversation(int conversationId) async {    try {
      final baseUrl = getBaseUrl();
      final url = '$baseUrl/conversations/$conversationId';
      final headers = await getHeaders();
      
      ApiLogger.logRequest('DELETE', url, headers, null);
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      
      ApiLogger.logResponse(url, response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      ApiLogger.logError('deleteConversation', e);
      throw Exception('Network error: $e');
    }
  }

  // Get all users
  static Future<List<User>> getUsers() async {
    try {
      final baseUrl = getBaseUrl();
      final url = '$baseUrl/users';
      final headers = await getHeaders();
      
      ApiLogger.logRequest('GET', url, headers, null);
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      ApiLogger.logResponse(url, response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true || data['success'] == 1) {
          return (data['data'] as List)
              .map((item) => User.fromJson(item))
              .toList();
        }
      }
      throw Exception('Failed to load users: ${response.body}');
    } catch (e) {
      ApiLogger.logError('getUsers', e);
      throw Exception('Network error: $e');
    }
  }
}