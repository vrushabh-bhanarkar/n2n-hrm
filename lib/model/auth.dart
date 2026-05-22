import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/Loginresponse.dart';
import 'package:cnattendance/services/presence_sync_service.dart';
import 'package:cnattendance/services/realtime_chat_service.dart';
import 'package:cnattendance/utils/http_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/utils/deviceuuid.dart';
import 'package:cnattendance/utils/constant.dart';

class Auth with ChangeNotifier {
  String appUrl = "";
  Preferences preferences = Preferences();

  Future<void> saveAppUrl(String value) async {
    try {
      String decoded = utf8.decode(base64.decode(value));

      if (!decoded.contains("http")) {
        showToast("Invalid QR Code");
        return;
      }
      preferences.saveAppUrl(decoded);
      appUrl = await preferences.getAppUrl();
      notifyListeners();
    } catch (e) {
      showToast("Invalid QR Code, Try again");
    }
  }

  Future<void> resetAppUrl() async {
    preferences.saveAppUrl("");
    appUrl = await preferences.getAppUrl();
    notifyListeners();
  }

  Future<void> skipAppUrl() async {
    preferences.saveAppUrl(Constant.appUrl);
    appUrl = await preferences.getAppUrl();
    notifyListeners();
  }

  Future<void> getAppUrl() async {
    appUrl = await preferences.getAppUrl();
    notifyListeners();
  }

  Future<Loginresponse> login(String username, String password) async {
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.LOGIN_URL);
    print(uri);

    Map<String, String> headers = {"Accept": "application/json; charset=UTF-8"};

    try {
      // Get FCM token with iOS APNS handling
      String? fcm;
      try {
        if (Platform.isIOS) {
          // For iOS, request APNS token first with multiple retries
          String? apnsToken;
          for (int i = 0; i < 3; i++) {
            apnsToken = await FirebaseMessaging.instance.getAPNSToken();
            if (apnsToken != null) {
              print('✅ APNS Token obtained on attempt ${i + 1}');
              break;
            }
            print('⚠️ APNS token not available, attempt ${i + 1}/3, waiting...');
            // Use a shorter retry delay to reduce perceived startup lag on simulators
            await Future.delayed(Duration(milliseconds: 300));
          }
          
          if (apnsToken == null) {
            print('⚠️ APNS token not available after retries - this is normal on simulator');
            print('⚠️ Continuing login with placeholder FCM token');
          }
        }
        
        fcm = await FirebaseMessaging.instance.getToken();
        print('📱 FCM Token: $fcm');
      } catch (e) {
        print('⚠️ Error getting FCM token: $e');
        // Continue with login - use a placeholder token
        fcm = 'SIMULATOR_TOKEN_UNAVAILABLE';
        print('⚠️ Using placeholder token for login');
      }
      
      // Use TimeoutHttpClient instead of regular http client
      final response = await TimeoutHttpClient.post(
        uri, 
        headers: headers, 
        body: {
          'username': username,
          'password': password,
          'fcm_token': fcm ?? 'SIMULATOR_TOKEN_UNAVAILABLE',
          'device_type': Platform.isIOS ? 'ios' : 'android',
          'uuid': await DeviceUUid().getUniqueDeviceId(),
        },
        timeout: Duration(seconds: 30), // 30 second timeout for login
      );

      print('📡 Login Response Status: ${response.statusCode}');
      print('📡 Login Response Body: ${response.body}');
      
      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        print(response.statusCode.toString());
        print(responseData.toString());

        Preferences preferences = Preferences();
        final responseJson = Loginresponse.fromJson(responseData);
        await preferences.saveUser(responseJson.data);

        final user = responseJson.data.user;
        await RealtimeChatService.initializeUserProfile(
          userId: user.id,
          name: user.name,
          email: user.email,
          username: user.username,
          branch: '',
          department: '',
          avatar: user.avatar,
        );
        await RealtimeChatService.setUserOnlineStatus(true);
        PresenceSyncService.startForegroundSync();

        return responseJson;
      } else {
        print('❌ Login failed with status ${response.statusCode}');
        print('❌ Error response: $responseData');
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } on TimeoutException {
      // Handle timeout specifically
      throw 'Connection timeout. Please check your internet and try again.';
    } on SocketException {
      // Handle network errors
      throw 'No internet connection. Please check your network.';
    } catch (error) {
      throw error;
    }
  }
}
