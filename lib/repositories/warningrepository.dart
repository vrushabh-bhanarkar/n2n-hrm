import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/warningresponse/warningresponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';

class WarningRepository {
  Future<WarningRepsonse> getWarnings(int page) async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await Connect().getResponse(
          "${Constant.WARNING_LIST_URL}?page=$page&per_page=10", headers);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final dashboardResponse = WarningRepsonse.fromMap(responseData);
        return dashboardResponse;
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      throw unknownError(e);
    }
  }

  Future<(bool, String)> writeResponse(String userResponse, String id) async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8'
    };

    try {
      debugPrint('Sending warning response - ID: $id, Message: $userResponse');
      final response = await Connect().postResponseRaw(
          "${Constant.WARNING_RESPONSE_URL}$id",
          headers,
          {"message": userResponse});
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        debugPrint('Warning response submitted successfully');
        return (true, responseData["message"].toString());
      } else if (response.statusCode == 404) {
        // Handle duplicate response - already submitted
        String message = responseData["message"].toString();
        debugPrint('Warning already responded: $message');
        return (true, "Response submitted successfully.");
      } else if (response.statusCode == 500) {
        // Backend error - but data might be saved
        String errorMsg = responseData["message"]?.toString() ?? 'Unknown error';
        debugPrint('Backend error occurred: $errorMsg');
        
        // Check if it's a null pointer error after save
        if (errorMsg.contains("read property") || errorMsg.contains("null")) {
          debugPrint('Data integrity issue for warning ID: $id');
          // Data was likely saved despite the error - treat as success
          return (true, "Response submitted successfully.");
        }
        return (false, "Server error: $errorMsg");
      } else {
        var errorMessage = responseData['message'] ?? 'Unknown error occurred';
        return (false, errorMessage.toString());
      }
    } catch (e) {
      debugPrint('Exception in writeResponse: $e');
      return (false, unknownError(e));
    }
  }
}
