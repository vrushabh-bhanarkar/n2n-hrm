import 'package:cnattendance/model/month.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_storage/get_storage.dart';

class Constant {
  // default production URL
  static const production = "https://n2nhrm2.n2nhostings.com";

  // Allow overriding MAIN_URL at build time using --dart-define=MAIN_URL=...
  // Example: flutter run -d <device> --dart-define=MAIN_URL=http://192.168.1.42:8000
  static const String MAIN_URL =
      const String.fromEnvironment('MAIN_URL', defaultValue: production);

  static const appUrl = MAIN_URL;

  static const API_URL = "api";
  static const PRIVACY_POLICY_URL = MAIN_URL + "/privacy";

  static const LOGIN_URL = "/api/login";
  static const LOGOUT_URL = "/api/logout";
  static const DASHBOARD_URL = "/api/dashboard";

  static const CHECK_IN_URL = "/api/employees/check-in";
  static const CHECK_OUT_URL = "/api/employees/check-out";
  static const ATTENDANCE_URL = "/api/employees/attendance";
  static const BREAK_REQUEST_URL = "/api/employees/break-request";
  static const EMPLOYEE_ATTENDANCE_STATUS_URL =
      "/api/employees/attendance-status";
  static const SEND_LOCATION = "/api/users/location";

  static const double OFFICE_LATITUDE = 27.6810411;
  static const double OFFICE_LONGITUDE = 85.3340921;
  static const double OFFICE_GEOFENCE_RADIUS_METERS = 1000;
  static const double OFFICE_LOCATION_MAX_ACCURACY_METERS = 100;

  // WiFi Auto Attendance (Router APIs)
  static const ROUTER_SSID_URL = "/api/router/ssid";
  static const WIFI_STATUS_URL = "/api/employees/wifi-status";
  // static const WIFI_AUTO_CHECKIN_URL = "/api/router/wifi-auto-checkin";
  // static const WIFI_AUTO_CHECKOUT_URL = "/api/router/wifi-auto-checkout";

  static const ADD_NFC_URL = "/api/nfc/store";

  static const ATTENDANCE_REPORT_URL = "/api/employees/attendance-detail";
  static const LEAVE_TYPE_URL = "/api/leave-types";
  static const LEAVE_TYPE_DETAIL_URL =
      "/api/leave-requests/employee-leave-requests";
  static const ISSUE_LEAVE = "/api/leave-requests/store";
  static const ISSUE_TIME_LEAVE = "/api/time-leave-requests/store";
  static const CANCEL_LEAVE = "/api/leave-requests/cancel";
  static const CANCEL_TIME_LEAVE = "/api/time-leave-requests/cancel";
  static const PROFILE_URL = "/api/users/profile";
  static const EMPLOYEE_PROFILE_URL = "/api/users/profile-detail";
  static const CONTENT_URL = "/api/static-page-content";
  static const TEAM_SHEET_URL = "/api/users/company/team-sheet";
  static const LEAVE_CALENDAR_API =
      "/api/leave-requests/employee-leave-calendar";
  static const LEAVE_CALENDAR_BY_DAY_API =
      "/api/leave-requests/employee-leave-list";
  static const OFFICE_CALENDAR_API = "/api/employee/office-calendar";
  static const HOLIDAYS_API = "/api/holidays";
  static const CHANGE_PASSWORD_API = "/api/users/change-password";
  static const RULES_API = "/api/company-rules";
  static const EDIT_PROFILE_URL = "/api/users/update-profile";
  static const NOTIFICATION_URL = "/api/notifications";
  static const SEND_PUSH_NOTIFICATION = "/api/employee/push";
  static const NOTICE_URL = "/api/notices";
  static const MEETING_URL = "/api/team-meetings";

  static const PROJECT_DASHBOARD_URL = "/api/project-management-dashboard";
  static const PROJECT_LIST_URL = "/api/assigned-projects-list";
  static const PROJECT_DETAIL_URL = "/api/assigned-projects-detail";
  static const TASK_LIST_URL = "/api/assigned-task-list";
  static const TASK_DETAIL_URL = "/api/assigned-task-detail";
  static const UPDATE_CHECKLIST_TOGGLE_URL =
      "/api/assigned-task-checklist/toggle-status";
  static const UPDATE_TASK_TOGGLE_URL =
      "/api/assigned-task-detail/change-status";
  static const EMPLOYEE_DETAIL_URL = "/api/users/profile-detail";
  static const GET_COMMENT_URL = "/api/assigned-task-comments";
  static const SAVE_COMMENT_URL = "/api/assigned-task/comments/store";
  static const DELETE_COMMENT_URL = "/api/assigned-task/comment/delete";
  static const DELETE_REPLY_URL = "/api/assigned-task/reply/delete";
  static const START_TASK_TIMER_URL = "/api/assigned-task";
  static const STOP_TASK_TIMER_URL = "/api/assigned-task";

  static const TADA_LIST_URL = "/api/employee/tada-lists";
  static const TADA_DETAIL_URL = "/api/employee/tada-details";
  static const TADA_STORE_URL = "/api/employee/tada/store";
  static const TADA_UPDATE_URL = "/api/employee/tada/update";
  static const TADA_DELETE_URL = "/api/employee/tada/delete";
  static const TADA_DELETE_ATTACHMENT_URL =
      "/api/employee/tada/delete-attachment";

  static const ADVANCE_SALARY_LIST_URL = "/api/employee/advance-salaries-lists";
  static const ADVANCE_SALARY_CREATE_URL =
      "/api/employee/advance-salaries/store";
  static const ADVANCE_SALARY_UPDATE_URL =
      "/api/employee/advance-salaries-detail/update";
  static const ADVANCE_SALARY_DETAIL_URL =
      "/api/employee/advance-salaries-detail";

  static const SUPPORT_URL = "/api/support/query-store";
  static const DEPARTMENT_LIST_URL = "/api/support/department-lists";
  static const SUPPORT_LIST_URL = "/api/support/get-user-query-lists";

  static const PAYSLIP_LIST_URL = "/api/employee/payslip";
  static const PAYSLIP_DETAIL_URL = "/api/employee/payslip/";
  static const PAYSLIP_DOWNLOAD_URL = "/employee/payslip/";

  static const APPLY_RESIGNATION_URL = "/api/resignation/store";
  static const RESIGNATION_URL = "/api/resignation/";

  static const TRAINING_LIST_URL = "/api/training/";
  static const EVENT_LIST_URL = "/api/events/";
  static const EVENT_DETAIL_URL = "/api/event/";

  static const AWARDS_URL = "/api/awards/";

  static const ASSETS_URL = "/api/assets/";
  static const ASSETS_RETURN_URL = "/api/asset-return/";

  static const WARNING_LIST_URL = "/api/warning";
  static const WARNING_RESPONSE_URL = "/api/warning/store/";

  static const COMPLAINT_LIST_URL = "/api/complaint";
  static const COMPLAINT_RESPONSE_URL = "/api/complaint/response/store/";
  static const COMPLAINT_APPLY_URL = "/api/complaint/store";

  static const EMPLOYEE_DEPARTMENT_URL = "/api/department-employees/";

  static const TOTAL_WORKING_HOUR = 8;
}

extension StringExtension on String {
  bool isUnique() {
    return true;
  }
}

void showToast(String message) {
  Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.white,
      textColor: Colors.black,
      fontSize: 12);
}

/// Deprecated: Use ErrorMapper.mapError() instead
/// This function is kept for backward compatibility but will be removed in future versions
@deprecated
String unknownError(e) {
  try {
    if (e is String) {
      return e.toString();
    } else if (e is Map) {
      var errorMessage = e['message'] ?? 'Unknown error occurred';
      return errorMessage.toString();
    } else if (e is Exception) {
      return e.toString();
    } else {
      return 'Unknown error: ${e.toString()}';
    }
  } catch (error) {
    return 'Error processing exception: ${error.toString()}';
  }
}

String findKey(dynamic data) {
  Map<String, dynamic> map;
  if (data is Map<String, dynamic>) {
    map = data;
  } else {
    // Handle the case where data might be a different type in newer nfc_manager versions
    try {
      map = Map<String, dynamic>.from(data as Map);
    } catch (e) {
      debugPrint("Error converting NFC data: $e");
      return "[]";
    }
  }

  for (var entry in map.entries) {
    if (entry.value is Map && entry.value['identifier'] != null) {
      List<int> identifierValue = List<int>.from(entry.value['identifier']);
      if (identifierValue.toString() != "[]") {
        debugPrint(identifierValue.toString());
        return identifierValue.toString();
      }
    }
  }
  return "[]";
}

final List<Month> engMonth = [
  Month(0, 'January'),
  Month(1, 'Febuary'),
  Month(2, 'March'),
  Month(3, 'April'),
  Month(4, 'May'),
  Month(5, 'June'),
  Month(6, 'July'),
  Month(7, 'August'),
  Month(8, 'September'),
  Month(9, 'October'),
  Month(10, 'November'),
  Month(11, 'December'),
];

final List<Month> nepaliMonth = [
  Month(0, 'Baisakh'),
  Month(1, 'Jestha'),
  Month(2, 'Asadh'),
  Month(3, 'Shwaran'),
  Month(4, 'Bhadra'),
  Month(5, 'Asoj'),
  Month(6, 'Kartik'),
  Month(7, 'Mangsir'),
  Month(8, 'Poush'),
  Month(9, 'Magh'),
  Month(10, 'Falgun'),
  Month(11, 'Chaitra'),
];

int calc() {
  return 10 - 5;
}

void value() {
  int value = calc();
}

bool getAppTheme() {
  final box = GetStorage();
  return box.read('theme') ?? true;
}

bool getAnimation() {
  final box = GetStorage();
  return box.read('animation') ?? true;
}

String appTheme = "#011754";
String appAlternateTheme = "#041033";

String radialBoxTheme = appAlternateTheme;

//light theme constant
String ltextColor = "#000000";

//dark theme constant
String dtextColor = "#ffffff";
