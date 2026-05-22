import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'package:cnattendance/data/source/network/model/dashboard/User.dart'
    as DashboardUser;
import 'package:cnattendance/data/source/network/model/login/Login.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Preferences with ChangeNotifier {
  final String USER_ID = "user_id";
  final String USER_AVATAR = "user_avatar";
  final String USER_TOKEN = "user_token";
  final String USER_EMAIL = "user_email";
  final String USER_NAME = "user_name";
  final String USER_FULLNAME = "user_fullname";
  final String USER_AUTH = "user_auth";
  final String WORKSPACE = "workspace_type";
  final String APP_IN_ENGLISH = "eng_date";
  final String ATTENDANCE_TYPE = "attendance_type";
  final String APP_URL = "app_url";
  final String HARD_RESET_APP = "HARD_RESET";
  final String BIRTHDAY_WISHED = "BIRTHDAY_WISHED";
  final String LAST_BIRTHDAY_WISHED_DATE = "LAST_BIRTHDAY_WISHED_DATE";
  final String SHOW_NFC = "SHOW_NFC";
  final String SHOWNOTE = "SHOW_NOTE";
  final String SHOWLOCATION = "SHOWLOCATION";

  //feature control
  final String PROJECT_MANAGEMENT = "project-management";
  final String MEETING = "meeting";
  final String TADA = "tada";
  final String PAYROLL_MANGEMENT = "payroll-management";
  final String ADVANCE_SALARY = "advance-salary";
  final String SUPPORT = "support";
  final String DARK_MODE = "dark-mode";
  final String NFC_QR = "nfc-qr";
  final String AWARD = "award";
  final String TRAINING = "training";
  final String LOAN = "loan";
  final String EVENT = "event";
  final String COMPLAIN = "COMPLAIN";
  final String WARNING = "WARNING";
  final String RESIGNATION = "RESIGNATION";
  final String ASSETS = "ASSETS";

  // WiFi Auto Attendance
  static const String WIFI_AUTO_ENABLED = "wifi_auto_enabled";
  static const String WIFI_OFFICE_BSSID = "wifi_office_bssid";
  static const String WIFI_OFFICE_SSID = "wifi_office_ssid";
  static const String WIFI_SERVER_SSIDS =
      "wifi_server_ssids"; // JSON array from /api/router/ssid
  static const String WIFI_CHECKIN_START_HOUR = "wifi_checkin_start_hour";
  static const String WIFI_CHECKIN_START_MIN = "wifi_checkin_start_min";
  static const String WIFI_CHECKIN_END_HOUR = "wifi_checkin_end_hour";
  static const String WIFI_CHECKIN_END_MIN = "wifi_checkin_end_min";
  static const String WIFI_CHECKOUT_START_HOUR = "wifi_checkout_start_hour";
  static const String WIFI_CHECKOUT_START_MIN = "wifi_checkout_start_min";
  static const String WIFI_CHECKOUT_END_HOUR = "wifi_checkout_end_hour";
  static const String WIFI_CHECKOUT_END_MIN = "wifi_checkout_end_min";
  static const String WIFI_SESSION_DATE = "wifi_auto_session_date";
  static const String WIFI_SESSION_STATUS = "wifi_auto_session_status";

  // WiFi Break Tracking
  static const String WIFI_FIRST_CHECKIN_TIME = "wifi_first_checkin_time";
  static const String WIFI_LAST_CHECKOUT_TIME = "wifi_last_checkout_time";
  static const String WIFI_BREAK_LOG = "wifi_break_log"; // JSON array
  static const String WIFI_BREAK_START_TIME = "wifi_break_start_time";
  static const String WIFI_TOTAL_BREAK_MINUTES = "wifi_total_break_minutes";
  static const String WIFI_LAST_WIFI_OFF_REMINDER =
      "wifi_last_wifi_off_reminder";
  static const String WIFI_LAST_MATCHED_BSSID = "wifi_last_matched_bssid";
  static const String WIFI_LAST_POLLED_STATUS = "wifi_last_polled_status";
  static const String WIFI_API_BACKOFF_UNTIL_MS = "wifi_api_backoff_until_ms";

  Future<bool> saveUser(Login data) async {
    // Obtain shared preferences.
    User user = data.user;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(USER_TOKEN, data.tokens);
    await prefs.setInt(USER_ID, user.id);
    await prefs.setString(USER_AVATAR, user.avatar);
    await prefs.setString(USER_EMAIL, user.email);
    await prefs.setString(USER_NAME, user.username);
    await prefs.setString(USER_FULLNAME, user.name);
    await prefs.setString(WORKSPACE, user.workspace_type);

    notifyListeners();

    return true;
  }

  Future<bool> saveUserDashboard(DashboardUser.User user) async {
    // Obtain shared preferences.
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(USER_ID, user.id);
    await prefs.setString(USER_AVATAR, user.avatar);
    await prefs.setString(USER_EMAIL, user.email);
    await prefs.setString(USER_NAME, user.username);
    await prefs.setString(USER_FULLNAME, user.name);
    await prefs.setString(WORKSPACE, user.workspace_type);

    notifyListeners();

    return true;
  }

  Future<void> setFeatures(Map<String, String> features) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
        PROJECT_MANAGEMENT, features["project-management"] ?? "0");
    await prefs.setString(MEETING, features["meeting"] ?? "0");
    await prefs.setString(TADA, features["tada"] ?? "0");
    await prefs.setString(
        PAYROLL_MANGEMENT, features["payroll-management"] ?? "0");
    await prefs.setString(ADVANCE_SALARY, features["advance-salary"] ?? "0");
    await prefs.setString(SUPPORT, features["support"] ?? "0");
    await prefs.setString(DARK_MODE, features["dark-mode"] ?? "0");
    await prefs.setString(NFC_QR, features["nfc-qr"] ?? "0");
    await prefs.setString(AWARD, features["award"] ?? "0");
    await prefs.setString(TRAINING, features["training"] ?? "0");
    await prefs.setString(LOAN, features["loan"] ?? "0");
    await prefs.setString(EVENT, features["event"] ?? "0");
    await prefs.setString(COMPLAIN, features["complaint"] ?? "0");
    await prefs.setString(WARNING, features["warning"] ?? "0");
    await prefs.setString(RESIGNATION, features["resignation"] ?? "0");
    await prefs.setString(ASSETS, features["assets"] ?? "0");

    notifyListeners();
  }

  Future<Map<String, String>> getFeatures() async {
    Map<String, String> features = <String, String>{};
    final prefs = await SharedPreferences.getInstance();

    features["project-management"] =
        await prefs.getString(PROJECT_MANAGEMENT) ?? "1";
    features["meeting"] = await prefs.getString(MEETING) ?? "1";
    features["tada"] = await prefs.getString(TADA) ?? "1";
    features["payroll-management"] =
        await prefs.getString(PAYROLL_MANGEMENT) ?? "1";
    features["advance-salary"] = await prefs.getString(ADVANCE_SALARY) ?? "1";
    features["support"] = await prefs.getString(SUPPORT) ?? "1";
    features["dark-mode"] = await prefs.getString(DARK_MODE) ?? "1";
    features["nfc-qr"] = await prefs.getString(NFC_QR) ?? "1";
    features["award"] = await prefs.getString(AWARD) ?? "1";
    features["training"] = await prefs.getString(TRAINING) ?? "1";
    features["loan"] = await prefs.getString(LOAN) ?? "1";
    features["event"] = await prefs.getString(EVENT) ?? "1";
    features["complaint"] = await prefs.getString(COMPLAIN) ?? "1";
    features["warning"] = await prefs.getString(WARNING) ?? "1";
    features["resignation"] = await prefs.getString(RESIGNATION) ?? "1";
    features["assets"] = await prefs.getString(ASSETS) ?? "1";

    return features;
  }

  void saveBasicUser(User user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(USER_ID, user.id);
    await prefs.setString(USER_AVATAR, user.avatar);
    await prefs.setString(USER_EMAIL, user.email);
    await prefs.setString(USER_NAME, user.username);
    await prefs.setString(USER_FULLNAME, user.name);

    notifyListeners();
  }

  Future<void> clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Preserve current app URL so users don't have to re-verify company
    final String preservedAppUrl = prefs.getString(APP_URL) ?? "";

    await prefs.setInt(USER_ID, 0);
    await prefs.setString(USER_TOKEN, '');
    await prefs.setString(USER_AVATAR, '');
    await prefs.setString(USER_EMAIL, '');
    await prefs.setString(USER_NAME, '');
    await prefs.setString(USER_FULLNAME, '');
    await prefs.setBool(USER_AUTH, false);
    await prefs.setBool(APP_IN_ENGLISH, true);
    await prefs.setString(WORKSPACE, "1");
    await prefs.setString(ATTENDANCE_TYPE, "Default");
    // Restore the preserved APP_URL after clearing sensitive fields
    await prefs.setString(APP_URL, preservedAppUrl);

    notifyListeners();
  }

  void saveUserAuth(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(USER_AUTH, value);
  }

  void saveShowNfc(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SHOW_NFC, value);
  }

  void saveHardReset(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(HARD_RESET_APP, value);
  }

  void saveAppUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(APP_URL, value);
  }

  void saveAttendanceType(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ATTENDANCE_TYPE, value);
    notifyListeners();
  }

  void saveAppEng(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(APP_IN_ENGLISH, value);
  }

  void saveBirthdayWished(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(BIRTHDAY_WISHED, value);
  }

  Future<String> getLastBirthdayWishedDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(LAST_BIRTHDAY_WISHED_DATE) ?? "";
  }

  Future<void> saveLastBirthdayWishedDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LAST_BIRTHDAY_WISHED_DATE, date);
  }

  void saveNote(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SHOWNOTE, value);
  }

  void saveEmployeeLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SHOWLOCATION, value);
  }

  Future<User> getUser() async {
    final prefs = await SharedPreferences.getInstance();

    return User(
        id: prefs.getInt(USER_ID) ?? 0,
        name: prefs.getString(USER_FULLNAME) ?? "",
        email: prefs.getString(USER_EMAIL) ?? "",
        username: prefs.getString(USER_NAME) ?? "",
        avatar: prefs.getString(USER_AVATAR) ?? "",
        workspace_type: prefs.getString(WORKSPACE) ?? "1");
  }

  Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(USER_TOKEN) ?? "";
  }

  Future<bool> getNote() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(SHOWNOTE) ?? false;
  }

  Future<bool> getEnableLocation() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(SHOWLOCATION) ?? false;
  }

  Future<String> getAttendanceType() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(ATTENDANCE_TYPE) ?? "Default";
  }

  Future<bool> getUserAuth() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(USER_AUTH) ?? false;
  }

  Future<int> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(USER_ID) ?? 0;
  }

  Future<bool> getShowNfc() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(SHOW_NFC) ?? true;
  }

  Future<bool> getBirthdayWished() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(BIRTHDAY_WISHED) ?? false;
  }

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_NAME) ?? "";
  }

  Future<String> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_EMAIL) ?? "";
  }

  Future<String> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_AVATAR) ?? "";
  }

  Future<String> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_FULLNAME) ?? "";
  }

  Future<String> getWorkSpace() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(WORKSPACE) ?? "1";
  }

  Future<bool> getEnglishDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(APP_IN_ENGLISH) ?? true;
  }

  Future<String> getAppUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(APP_URL) ?? Constant.appUrl;
  }

  Future<bool> getHardReset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(HARD_RESET_APP) ?? true;
  }

  // ========================
  // WiFi Auto Attendance
  // ========================

  Future<void> saveWifiAutoEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WIFI_AUTO_ENABLED, value);
  }

  Future<bool> getWifiAutoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(WIFI_AUTO_ENABLED) ?? false;
  }

  Future<void> saveWifiOfficeBssid(String bssid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WIFI_OFFICE_BSSID, bssid);
  }

  Future<String> getWifiOfficeBssid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(WIFI_OFFICE_BSSID) ?? '';
  }

  Future<void> saveWifiOfficeSsid(String ssid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WIFI_OFFICE_SSID, ssid);
  }

  Future<String> getWifiOfficeSsid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(WIFI_OFFICE_SSID) ?? '';
  }

  Future<void> saveWifiServerSsids(String jsonArray) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WIFI_SERVER_SSIDS, jsonArray);
  }

  Future<String> getWifiServerSsids() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(WIFI_SERVER_SSIDS) ?? '[]';
  }

  Future<void> saveWifiCheckinWindow(
      int startHour, int startMin, int endHour, int endMin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(WIFI_CHECKIN_START_HOUR, startHour);
    await prefs.setInt(WIFI_CHECKIN_START_MIN, startMin);
    await prefs.setInt(WIFI_CHECKIN_END_HOUR, endHour);
    await prefs.setInt(WIFI_CHECKIN_END_MIN, endMin);
  }

  Future<void> saveWifiCheckoutWindow(
      int startHour, int startMin, int endHour, int endMin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(WIFI_CHECKOUT_START_HOUR, startHour);
    await prefs.setInt(WIFI_CHECKOUT_START_MIN, startMin);
    await prefs.setInt(WIFI_CHECKOUT_END_HOUR, endHour);
    await prefs.setInt(WIFI_CHECKOUT_END_MIN, endMin);
  }

  Future<Map<String, int>> getWifiCheckinWindow() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'startHour': prefs.getInt(WIFI_CHECKIN_START_HOUR) ?? 8,
      'startMin': prefs.getInt(WIFI_CHECKIN_START_MIN) ?? 0,
      'endHour': prefs.getInt(WIFI_CHECKIN_END_HOUR) ?? 11,
      'endMin': prefs.getInt(WIFI_CHECKIN_END_MIN) ?? 0,
    };
  }

  Future<Map<String, int>> getWifiCheckoutWindow() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'startHour': prefs.getInt(WIFI_CHECKOUT_START_HOUR) ?? 16,
      'startMin': prefs.getInt(WIFI_CHECKOUT_START_MIN) ?? 0,
      'endHour': prefs.getInt(WIFI_CHECKOUT_END_HOUR) ?? 21,
      'endMin': prefs.getInt(WIFI_CHECKOUT_END_MIN) ?? 0,
    };
  }

  Future<void> saveWifiSessionStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayDateString();
    await prefs.setString(WIFI_SESSION_DATE, today);
    await prefs.setString(WIFI_SESSION_STATUS, status);
  }

  /// Returns "none" if session is from a previous day (resets the session).
  Future<String> getWifiSessionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(WIFI_SESSION_DATE) ?? '';
    final today = _todayDateString();
    if (savedDate != today) {
      await _resetDailySession(prefs, today);
      return 'none';
    }
    return prefs.getString(WIFI_SESSION_STATUS) ?? 'none';
  }

  // ========================
  // WiFi Break Tracking
  // ========================

  Future<void> saveWifiFirstCheckinTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WIFI_FIRST_CHECKIN_TIME, time);
  }

  Future<String> getWifiFirstCheckinTime() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(WIFI_SESSION_DATE) ?? '';
    if (savedDate != _todayDateString()) return '';
    return prefs.getString(WIFI_FIRST_CHECKIN_TIME) ?? '';
  }

  Future<void> saveWifiLastCheckoutTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WIFI_LAST_CHECKOUT_TIME, time);
  }

  Future<String> getWifiLastCheckoutTime() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(WIFI_SESSION_DATE) ?? '';
    if (savedDate != _todayDateString()) return '';
    return prefs.getString(WIFI_LAST_CHECKOUT_TIME) ?? '';
  }

  Future<void> saveWifiBreakStartTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WIFI_BREAK_START_TIME, time);
  }

  Future<String> getWifiBreakStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(WIFI_BREAK_START_TIME) ?? '';
  }

  Future<void> saveWifiBreakLog(String jsonLog) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WIFI_BREAK_LOG, jsonLog);
  }

  Future<String> getWifiBreakLog() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(WIFI_SESSION_DATE) ?? '';
    if (savedDate != _todayDateString()) return '[]';
    return prefs.getString(WIFI_BREAK_LOG) ?? '[]';
  }

  Future<void> saveWifiTotalBreakMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(WIFI_TOTAL_BREAK_MINUTES, minutes);
  }

  Future<int> getWifiTotalBreakMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(WIFI_SESSION_DATE) ?? '';
    if (savedDate != _todayDateString()) return 0;
    return prefs.getInt(WIFI_TOTAL_BREAK_MINUTES) ?? 0;
  }

  Future<void> _resetDailySession(SharedPreferences prefs, String today) async {
    await prefs.setString(WIFI_SESSION_DATE, today);
    await prefs.setString(WIFI_SESSION_STATUS, 'none');
    await prefs.setString(WIFI_FIRST_CHECKIN_TIME, '');
    await prefs.setString(WIFI_LAST_CHECKOUT_TIME, '');
    await prefs.setString(WIFI_BREAK_LOG, '[]');
    await prefs.setString(WIFI_BREAK_START_TIME, '');
    await prefs.setInt(WIFI_TOTAL_BREAK_MINUTES, 0);
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
