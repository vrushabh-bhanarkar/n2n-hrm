
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/teamsheet/Teamsheetresponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/exceptions/app_exceptions.dart';
import 'package:cnattendance/utils/error_mapper.dart';

class TeamSheetRepository {
  Future<Teamsheetresponse> getTeam() async {
    Preferences preferences = Preferences();

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await Connect().getResponse(Constant.TEAM_SHEET_URL, headers);
      log('Team Sheet API Response: ${response.statusCode}');

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        log('Team Sheet Data: ${responseData.toString()}');

        final responseJson = Teamsheetresponse.fromJson(responseData);
        return responseJson;
      } else {
        // Map HTTP error to appropriate exception
        throw ErrorMapper.mapError(responseData, response: response);
      }
    } on SocketException {
      // Network connectivity error
      throw NoInternetException();
    } on FormatException catch (e) {
      // JSON parsing error
      throw DataParseException(
        'Failed to parse team sheet data',
        originalError: e,
      );
    } on AppException {
      // Re-throw AppExceptions as-is
      rethrow;
    } catch (error) {
      // Map any other error to appropriate exception
      throw ErrorMapper.mapError(error);
    }
  }
}