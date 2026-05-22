import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/departmentlistresponse/departmentlistresponse.dart';
import 'package:cnattendance/data/source/network/model/support/SupportResponse.dart';
import 'package:cnattendance/model/department.dart';
import 'package:cnattendance/screen/profile/supportlistscreen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class SupportController extends GetxController {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  var selected = Department("0", "").obs;

  var departments = <Department>[].obs;

  var isLoadingDepartments = true.obs;

  final form = GlobalKey<FormState>();

  void onSubmitClicked() {
    if (form.currentState!.validate()) {
      if (selected.value.id != "0" && selected.value.id.isNotEmpty) {
        sendSupportMessage(titleController.text, descriptionController.text);
      } else {
        Get.snackbar(
          'Error',
          'Please select a department',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<SupportResponse> sendSupportMessage(
      String title, String description) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.SUPPORT_URL);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    debugPrint('🎫 Sending support request to: $uri');
    debugPrint('🎫 Department ID: ${selected.value.id}');
    debugPrint('🎫 Title: $title');

    try {
      EasyLoading.show(
          status: 'Submitting, Please Wait...',
          maskType: EasyLoadingMaskType.black);
      final response = await http.post(uri, headers: headers, body: {
        "title": title,
        "description": description,
        "department_id": selected.value.id.toString()
      });

      debugPrint('🎫 Support response status: ${response.statusCode}');
      debugPrint('🎫 Support response body: ${response.body}');

      final responseData = json.decode(response.body);

      EasyLoading.dismiss(animation: true);

      if (response.statusCode == 200) {
        final supportResponse = SupportResponse.fromJson(responseData);

        titleController.clear();
        descriptionController.clear();

        Get.dialog(
            Container(
                margin: EdgeInsets.all(20),
                width: double.infinity,
                height: 500,
                child:
                    Center(child: CustomAlertDialog(supportResponse.message))),
            barrierDismissible: false);
        return supportResponse;
      } else if (response.statusCode == 403) {
        // Unauthorized/Forbidden
        var errorMessage = responseData['message'] ?? 
            'You do not have permission to submit support requests. Please contact your administrator.';
        Get.snackbar(
          'Permission Denied',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 5),
        );
        throw errorMessage;
      } else {
        var errorMessage = responseData['message'] ?? 'Failed to submit support request';
        Get.snackbar(
          'Error',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 4),
        );
        throw errorMessage;
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      throw unknownError(e);
    }
  }

  Future<void> getDepartments() async {
    try {
      isLoadingDepartments.value = true;
      Preferences preferences = Preferences();
      var uri = Uri.parse(
          await preferences.getAppUrl() + Constant.DEPARTMENT_LIST_URL);

      String token = await preferences.getToken();

      Map<String, String> headers = {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token'
      };

      final response = await http.get(uri, headers: headers);

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final departmentResponse =
            departmentlistresponse.fromJson(responseData);

        departments.clear();
        for (var department in departmentResponse.data) {
          departments
              .add(Department(department.id.toString(), department.dept_name));
        }
      } else {
        var errorMessage =
            responseData['message'] ?? 'Failed to load departments';
        Get.snackbar(
          'Error',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        throw errorMessage;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load departments. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingDepartments.value = false;
    }
  }

  void showList() {
    Get.to(SupportListScreen(), transition: Transition.cupertino);
  }

  @override
  void onInit() {
    getDepartments();
    super.onInit();
  }
}
