import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/leaveissue/IssueLeaveResponse.dart';
import 'package:cnattendance/data/source/network/model/tadadetail/tadadetailresponse.dart';
import 'package:cnattendance/data/source/network/model/tadalist/tadalistresponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/exceptions/app_exceptions.dart';
import 'package:cnattendance/utils/error_mapper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TadaRepository {
  Future<TadaListResponse> getTadaList() async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response =
          await Connect().getResponse(Constant.TADA_LIST_URL, headers);
      debugPrint('TADA List Response: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final tadaResponse = TadaListResponse.fromJson(responseData);
        return tadaResponse;
      } else {
        throw ErrorMapper.mapError(responseData, response: response);
      }
    } on SocketException {
      throw NoInternetException();
    } on FormatException catch (e) {
      throw DataParseException('Failed to parse TADA list data', originalError: e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ErrorMapper.mapError(e);
    }
  }

  Future<TadaDetailResponse> getTadaDetail(String tadaId) async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await Connect()
          .getResponse(Constant.TADA_DETAIL_URL + "/$tadaId", headers);
      debugPrint('TADA Detail Response: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final tadaResponse = TadaDetailResponse.fromJson(responseData);
        return tadaResponse;
      } else {
        throw ErrorMapper.mapError(responseData, response: response);
      }
    } on SocketException {
      throw NoInternetException();
    } on FormatException catch (e) {
      throw DataParseException('Failed to parse TADA detail data', originalError: e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ErrorMapper.mapError(e);
    }
  }

  Future<bool> deleteTada(String tadaId) async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await Connect()
          .postResponse(Constant.TADA_DELETE_URL + "/$tadaId", headers, {});
      debugPrint('TADA Delete Response: ${response.statusCode}');
      debugPrint('Content-Type: ${response.headers['content-type']}');
      debugPrint('Response body length: ${response.body.length}');

      // Check if response is HTML instead of JSON (common for 404 errors)
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html')) {
        throw DataParseException(
          'Endpoint returned HTML. The TADA delete endpoint may not exist or is misconfigured. '
          'Status: ${response.statusCode}',
        );
      }

      // Try to parse as JSON only if status is successful
      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          return true;
        } on FormatException catch (e) {
          // If JSON parsing fails but status is 200, still consider it success
          // (backend might not return JSON for delete)
          debugPrint('Warning: Could not parse delete response as JSON, but status is 200');
          return true;
        }
      } else {
        // Try to parse as JSON for error details
        try {
          final responseData = json.decode(response.body);
          throw ErrorMapper.mapError(responseData, response: response);
        } on FormatException {
          throw ErrorMapper.mapError(
            {'message': 'Server returned error: ${response.statusCode}'},
            response: response,
          );
        }
      }
    } on SocketException {
      throw NoInternetException();
    } on AppException {
      rethrow;
    } catch (e) {
      throw ErrorMapper.mapError(e);
    }
  }

  Future<IssueLeaveResponse> createTada(String title, String description,
      String expenses, List<PlatformFile> fileList) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.TADA_STORE_URL);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Content-type': 'multipart/form-data',
      'Authorization': 'Bearer $token'
    };

    var requests = http.MultipartRequest('POST', uri);
    requests.headers.addAll(headers);

    requests.fields.addAll({
      "title": title,
      "description": description,
      "total_expense": expenses,
    });

    for (var filed in fileList) {
      final file = File(filed.path!);
      final stream = http.ByteStream(Stream.castFrom(file.openRead()));
      final length = await file.length();

      final multipartFile = http.MultipartFile('attachments[]', stream, length,
          filename: filed.name);
      requests.files.add(multipartFile);
    }
    final responseStream = await requests.send();

    final response = await http.Response.fromStream(responseStream);
    debugPrint(response.toString());
    try {
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final tadaResponse = IssueLeaveResponse.fromJson(responseData);
        return tadaResponse;
      } else {
        throw ErrorMapper.mapError(responseData, response: response);
      }
    } on FormatException catch (e) {
      throw DataParseException('Failed to parse TADA creation response', originalError: e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ErrorMapper.mapError(e);
    }
  }

  Future<bool> getIsAd() async {
    Preferences preferences = Preferences();
    return await preferences.getEnglishDate();
  }
}
