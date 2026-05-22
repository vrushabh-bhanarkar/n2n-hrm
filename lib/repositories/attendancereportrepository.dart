import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/attendancereport/AttendanceReportResponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/exceptions/app_exceptions.dart';
import 'package:cnattendance/utils/error_mapper.dart';

class AttendanceReportRepository {
  Future<AttendanceReportResponse> getAttendanceReport(
      int selectedMonth) async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };
    
    try {
      final response = await Connect().getResponse(
          Constant.ATTENDANCE_REPORT_URL + "?month=${selectedMonth + 1}",
          headers);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        log('Attendance Report Data: ${responseData.toString()}');

        final responseJson = AttendanceReportResponse.fromJson(responseData);
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
        'Failed to parse attendance report data',
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

  Future<bool> getDateInAd() async {
    Preferences preferences = Preferences();
    bool value = await preferences.getEnglishDate();

    return value;
  }
}
