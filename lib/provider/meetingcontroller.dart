import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/meeting/MeetingDomain.dart';
import 'package:cnattendance/data/source/network/model/meeting/MeetingReponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

// TODO: DEF_32 - Meeting Notification Issue
// If notifications are not appearing after meeting creation, check:
// 1. Backend API sends FCM notification when meeting is created
// 2. FCM server key is properly configured in backend
// 3. Meeting creation endpoint triggers notification service
// 4. Check backend logs for notification dispatch
// The frontend FCM service and notification infrastructure is properly set up

class MeetingController extends GetxController {
  static int per_page = 10;
  int page = 1;

  var _meetingList = <MeetingDomain>[].obs;

  List<MeetingDomain> get meetingList {
    return [..._meetingList];
  }

  Future<MeetingReponse> getMeetingList() async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl()+Constant.MEETING_URL).replace(queryParameters: {
      'page': page.toString(),
      'per_page': per_page.toString(),
    });

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(status: translate('loader.loading'),maskType: EasyLoadingMaskType.black);
      final response = await http.get(uri, headers: headers);
      EasyLoading.dismiss(animation: true);
      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        debugPrint(responseData.toString());

        final responseJson = MeetingReponse.fromJson(responseData);

        makeMeetingList(responseJson.data);
        return responseJson;
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      EasyLoading.dismiss(animation: true);
      throw error;
    }
  }

  void makeMeetingList(List<MeetingDomain> data) {
    if (page == 1) {
      _meetingList.clear();
    }

    if (data.isNotEmpty) {
      for (var item in data) {
        _meetingList.add(item);
      }

      page++;
    }
  }

  @override
  void onReady() {
    getMeetingList();
    super.onReady();
  }
}
