import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:get_storage/get_storage.dart';

/// FCM Token Manager for sending tokens to Laravel backend
class FCMTokenManager {
  // 🔄 CHANGE THIS to your actual Laravel URL
  static String baseUrl = 'http://10.0.2.2:8000'; // Android emulator localhost (change to your Laravel URL)
  
  /// Send FCM token to Laravel when user logs in
  static Future<void> sendTokenToLaravel(int userId) async {
    try {
      print('📱 Getting FCM token for user $userId...');
      
      // Get FCM token
      String? token = await FirebaseMessaging.instance.getToken();
      print('📱 FCM Token: ${token?.substring(0, 20)}...');
      
      if (token != null) {
        // Send token to Laravel
        final response = await http.post(
          Uri.parse('$baseUrl/api/fcm/store-token'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'user_id': userId,
            'token': token,
            'device_type': Platform.isAndroid ? 'android' : 'ios',
          }),
        );
        
        if (response.statusCode == 200) {
          print('✅ FCM Token sent to Laravel successfully');
          
          // Store locally for future reference
          final storage = GetStorage();
          await storage.write('fcm_token', token);
          await storage.write('fcm_user_id', userId);
        } else {
          print('❌ Failed to send FCM Token: ${response.statusCode} - ${response.body}');
        }
      } else {
        print('❌ FCM Token is null');
      }
    } catch (e) {
      print('❌ FCM Token error: $e');
    }
  }
  
  /// Update token when app starts (if user already logged in)
  static Future<void> updateTokenOnAppStart() async {
    try {
      final storage = GetStorage();
      int? userId = storage.read('fcm_user_id');
      
      if (userId != null) {
        print('📱 Updating FCM token on app start for user $userId');
        await sendTokenToLaravel(userId);
      } else {
        print('📱 No user logged in, skipping token update');
      }
    } catch (e) {
      print('❌ Error updating token on app start: $e');
    }
  }
  
  /// Remove token when user logs out
  static Future<void> removeTokenOnLogout(int userId) async {
    try {
      print('📱 Removing FCM token for user $userId');
      
      await http.post(
        Uri.parse('$baseUrl/api/fcm/remove-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      );
      
      // Clear local storage
      final storage = GetStorage();
      await storage.remove('fcm_token');
      await storage.remove('fcm_user_id');
      
      print('✅ FCM Token removed from Laravel');
    } catch (e) {
      print('❌ Remove token error: $e');
    }
  }
  
  /// Get current stored token (for debugging)
  static Future<String?> getCurrentToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      print('📱 Current FCM Token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      print('❌ Error getting current token: $e');
      return null;
    }
  }
  
}