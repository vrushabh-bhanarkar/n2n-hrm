import 'dart:convert';
import 'dart:async';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/logout/Logoutresponse.dart';
import 'package:cnattendance/services/presence_sync_service.dart';
import 'package:cnattendance/services/realtime_chat_service.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/api_response_handler.dart';
import 'package:cnattendance/utils/http_client.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:cnattendance/utils/logging_middleware.dart';

class MoreScreenProvider with ChangeNotifier {
  late Map<String, String> features = {};
  bool showNfc = true;

  void changeAttendanceMethod(String type) {
    Preferences preferences = Preferences();
    preferences.saveAttendanceType(type);
    notifyListeners();
  }

  Future<void> getFeatures() async {
    Preferences preferences = Preferences();
    features = await preferences.getFeatures();
    showNfc = await preferences.getShowNfc();
    notifyListeners();
  }

  Future<Logoutresponse> logout() async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.LOGOUT_URL);
    String token = await preferences.getToken();
    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };
    try {
      final response = await TimeoutHttpClient.get(
        uri, 
        headers: headers,
        timeout: Duration(seconds: 30),
      );
      debugPrint('📤 LOGOUT API Response Status: ${response.statusCode}');
      debugPrint('📤 LOGOUT API Response Body: ${response.body}');

      final responseData = ApiResponseHandler.parseResponse(response);

      if (response.statusCode == 200) {
        // Normalize logout_status from API (handle string or int)
        final dynamic data = responseData['data'];
        final dynamic rawStatus = data != null ? data['logout_status'] : null;
        final int? logoutStatus = rawStatus == null
            ? null
            : (rawStatus is int ? rawStatus : int.tryParse(rawStatus.toString()));
        final String statusText = (data != null ? (data['logout_status_text']?.toString() ?? '') : '').toLowerCase();
        final String messageText = (responseData['message']?.toString() ?? '').toLowerCase();

        debugPrint('📤 Detected logout_status: $logoutStatus (raw: $rawStatus)');
        debugPrint('📤 Detected logout_status_text: $statusText');
        debugPrint('📤 Message text: $messageText');

        // Pending: show waiting screen, don't clear prefs
        final bool looksPending =
            logoutStatus == 1 ||
            statusText == 'pending' ||
            messageText.contains('partial logout') ||
            messageText.contains('pending') ||
            messageText.contains('approval');

        if (looksPending) {
          debugPrint('✅ LOGOUT IS PENDING - Returning 202');
          return Logoutresponse(
            status: true,
            message: "Logout pending admin approval",
            statusCode: 202,
          );
        }

        // Approved or immediate logout
        debugPrint('✅ LOGOUT APPROVED - Clearing preferences');
        final jsonResponse = Logoutresponse.fromJson(responseData);
        PresenceSyncService.stopForegroundSync();
        await RealtimeChatService.setUserOnlineStatus(false);
        await preferences.clearPrefs();
        return jsonResponse;
      } else if (response.statusCode == 401) {
        // Token invalid/expired - treat as logged out
        debugPrint('⚠️ 401 Response - Treating as logged out');
        PresenceSyncService.stopForegroundSync();
        await RealtimeChatService.setUserOnlineStatus(false);
        await preferences.clearPrefs();
        return Logoutresponse(
          status: true,
          message: "Logged out",
          statusCode: 401,
        );
      }

      // Non-200: surface error without clearing prefs
      throw responseData['message'] ?? 'Logout failed with status ${response.statusCode}';
    } catch (e) {
      // Do not clear preferences on network/parse errors in approval flow
      debugPrint('❌ LOGOUT Error: $e');
      rethrow;
    }
  }

  Future<String> getDeviceName() async {
    Map deviceInfo = (await DeviceInfoPlugin().deviceInfo).data;
    String? brand = deviceInfo['brand'];
    String? model = deviceInfo['model'];
    String? name = deviceInfo['name'];

    return ("${name ?? ""} ${brand ?? ""} ${model ?? ""}");
  }

  Future<void> addNfcApi(String title, String identifier) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.ADD_NFC_URL);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    final http.Client client = await LoggingMiddleware.create();

    try {
      final response = await client.post(uri, headers: headers, body: {
        'title': await getDeviceName(),
        'identifier': identifier,
      });

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } finally {
      client.close();
    }
  }
}
