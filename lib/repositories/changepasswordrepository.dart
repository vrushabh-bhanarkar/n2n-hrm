import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/changepassword/ChangePasswordResponse.dart';
import 'package:cnattendance/utils/constant.dart';

class ChangePasswordRepository{
  Future<ChangePasswordResponse> changePassword(
      String old, String newPassword, String confirm) async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Authorization': 'Bearer $token',
      HttpHeaders.contentTypeHeader: "application/json"
    };

    final body = {
      'current_password': old,
      'new_password': newPassword,
      'confirm_password': confirm,
    };

    try {
      final response = await Connect().postResponseRaw(Constant.CHANGE_PASSWORD_API, headers, body);

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final jsonResponse = ChangePasswordResponse.fromJson(responseData);

        return jsonResponse;
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      throw unknownError(e);
    }
  }
}