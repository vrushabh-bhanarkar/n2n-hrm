import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'dart:math' as Random;
import 'dart:async';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/attendancestatus/AttendanceStatus.dart';
import 'package:cnattendance/data/source/network/model/attendancestatus/AttendanceStatusResponse.dart';
import 'package:cnattendance/data/source/network/model/dashboard/Dashboardresponse.dart';
import 'package:cnattendance/data/source/network/model/dashboard/EmployeeTodayAttendance.dart';
import 'package:cnattendance/data/source/network/model/dashboard/Feature.dart';
import 'package:cnattendance/data/source/network/model/dashboard/Overview.dart';
import 'package:cnattendance/data/source/network/model/eventlistresponse/eventdetailresponse.dart';
import 'package:cnattendance/data/source/network/model/teamsheet/Employee.dart'
    as employees;
import 'package:cnattendance/data/source/network/model/trainingresponse/trainingresponse.dart';
import 'package:cnattendance/model/award.dart';
import 'package:cnattendance/model/holiday.dart';
import 'package:cnattendance/services/presence_sync_service.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/locationstatus.dart';
import 'package:cnattendance/utils/wifiinfo.dart';
import 'package:cnattendance/utils/api_response_handler.dart';
import 'package:cnattendance/utils/http_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
// ...existing code...
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:cnattendance/utils/logging_middleware.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';

const String _kInternetConnectionMessage =
    'Please check your internet connection';
const String _kBreakExceededCheckInMessage =
    'Break time is exceeded. Please submit a break extension request before checking in.';

bool _isNetworkError(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException) {
    return true;
  }

  final message = error.toString().toLowerCase();
  return message.contains('failed host lookup') ||
      message.contains('socketexception') ||
      message.contains('connection reset') ||
      message.contains('connection abort') ||
      message.contains('timed out') ||
      message.contains('timeout');
}

String _userFriendlyAttendanceError(Object error) {
  if (_isNetworkError(error)) {
    return _kInternetConnectionMessage;
  }
  return error.toString();
}

class DashboardProvider with ChangeNotifier {
  final Map<String, String> _overviewList = {
    'present': '0',
    'holiday': '0',
    'leave': '0',
    'request': '0',
    'total_project': '0',
    'total_task': '0',
    'total_awards': '0',
    'active_training': '0',
    'active_event': '0',
  };

  late Map<String, String> features = {};

  final Map<String, double> locationStatus = {
    'latitude': 0.0,
    'longitude': 0.0,
  };

  var department = "";
  var branch = "";

  Map<String, String> get overviewList {
    return _overviewList;
  }

  final Map<String, dynamic> _attendanceList = {
    'check-in': '-',
    'check-out': '-',
    'is_on_break': false,
    'production_hour': '0 hr 0 min',
    'allowed_break_time_minutes': 0,
    'break_used_minutes': 0,
    'remaining_break_time_minutes': 0,
    'allowed_break_time': '0 min',
    'break_used_time': '0 min',
    'remaining_break_time': '0 min',
    'remaining_break_time_percent': 0.0,
    'production-time': 0.0
  };

  List<employees.Employee> employeeList = [];

  bool isAD = true;
  bool isNoteEnabled = false;
  bool isLocationEnabled = false;
  bool animated = true;
  bool isBirthdayWished = false;

  Holiday? holiday;
  Award? award;
  Training? training;
  EventApi? event;

  final noteController = TextEditingController();

  Map<String, dynamic> get attendanceList {
    return _attendanceList;
  }

  int _attendanceMinutes(String key) {
    final value = _attendanceList[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  bool _isAttendanceActive() {
    final checkIn = (_attendanceList['check-in'] ?? '-').toString();
    final checkOut = (_attendanceList['check-out'] ?? '-').toString();
    return checkIn != '-' && checkOut == '-';
  }

  bool _isBreakExceeded({
    required int allowedBreakMinutes,
    required int breakUsedMinutes,
    required int remainingBreakMinutes,
  }) {
    if (allowedBreakMinutes <= 0) {
      return false;
    }

    if (remainingBreakMinutes > 0) {
      return false;
    }

    // Some server payloads can be inconsistent for break values.
    // If remaining is exactly zero, confirm using used-vs-allowed minutes.
    if (remainingBreakMinutes == 0) {
      return breakUsedMinutes >= allowedBreakMinutes;
    }

    return true;
  }

  bool _isCheckInBlockedByBreak({String? explicitStatusType}) {
    // Break approval/extension is authoritative on server-side. Client-side
    // cached values can be stale and incorrectly block a valid check-in.
    return false;
  }

  final List<double> _weeklyReport = [];

  List<double> get weeklyReport {
    return _weeklyReport;
  }

  List<BarChartGroupData> barchartValue = [];

  List<BarChartGroupData> rawBarGroups = [];
  List<BarChartGroupData> showingBarGroups = [];

  // WiFi SSID cache for faster attendance check-in
  List<dynamic> _cachedServerSsids = [];
  DateTime? _ssidCacheTime;
  static const Duration _ssidCacheDuration = Duration(minutes: 5);

  void buildgraph() {
    const int daysInWeek = 7;
    for (int i = 0; i < daysInWeek; i++) {
      barchartValue.add(makeGroupData(i, 0));
    }

    rawBarGroups.addAll(barchartValue);
    showingBarGroups.addAll(rawBarGroups);
  }

  Future<void> checkAD() async {
    Preferences preferences = Preferences();
    isAD = await preferences.getEnglishDate();
    notifyListeners();
  }

  Future<void> getFeatures() async {
    Preferences preferences = Preferences();
    features = await preferences.getFeatures();
    notifyListeners();
  }

  Future<http.Response> _fetchDashboardWithRetry(
    Uri uri,
    Map<String, String> headers,
  ) async {
    const timeout = Duration(seconds: 30);
    const retryDelay = Duration(milliseconds: 600);

    try {
      return await TimeoutHttpClient.get(
        uri,
        headers: headers,
        timeout: timeout,
      );
    } on TimeoutException {
      await Future.delayed(retryDelay);
      return TimeoutHttpClient.get(
        uri,
        headers: headers,
        timeout: timeout,
      );
    } on http.ClientException catch (e) {
      final msg = e.message.toLowerCase();
      final isTransientTransport = msg.contains('failed host lookup') ||
          msg.contains('connection abort') ||
          msg.contains('connection reset') ||
          msg.contains('socketexception');

      if (!isTransientTransport) rethrow;

      await Future.delayed(retryDelay);
      return TimeoutHttpClient.get(
        uri,
        headers: headers,
        timeout: timeout,
      );
    }
  }

  Future<Dashboardresponse> getDashboard() async {
    Preferences preferences = Preferences();
    animated = getAnimation();
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.DASHBOARD_URL);

    // Keep backend online status updated before dashboard is fetched.
    await PresenceSyncService.markOnlineViaBackend();

    String token = await preferences.getToken();

    var fcm = await FirebaseMessaging.instance.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
      'fcm_token': fcm ?? ""
    };

    final response = await _fetchDashboardWithRetry(uri, headers);
    log(response.body.toString());
    final responseData = ApiResponseHandler.parseResponse(response);

    if (response.statusCode == 200) {
      final dashboardResponse = Dashboardresponse.fromJson(responseData);

      department = dashboardResponse.data.user.department;
      branch = dashboardResponse.data.user.branch;

      if (dashboardResponse.data.user.dob != "") {
        final dob =
            DateFormat("yyyy-MM-dd").parse(dashboardResponse.data.user.dob);
        final currentDate = DateTime.now();
        final isBirthday =
            dob.month == currentDate.month && currentDate.day == dob.day;

        if (isBirthday) {
          // Check if we've already shown the birthday wish today
          final lastWishedDate = await preferences.getLastBirthdayWishedDate();
          final today = DateFormat("yyyy-MM-dd").format(currentDate);

          if (lastWishedDate != today) {
            // It's their birthday and we haven't shown the popup today
            isBirthdayWished = false;
            await preferences.saveLastBirthdayWishedDate(today);
          } else {
            // Already shown today
            isBirthdayWished = true;
          }
        } else {
          // Not their birthday, don't show popup
          isBirthdayWished = true;
        }
      } else {
        // No date of birth, don't show popup
        isBirthdayWished = true;
      }

      updateAttendanceStatus(dashboardResponse.data.employeeTodayAttendance);
      updateOverView(dashboardResponse.data.overview);

      makeWeeklyReport(dashboardResponse.data.employeeWeeklyReport);
      controlFeatures(dashboardResponse.data.features);
      await preferences.saveUserDashboard(dashboardResponse.data.user);

      employeeList = dashboardResponse.data.employee;
      preferences.saveShowNfc(dashboardResponse.data.addNfc);
      preferences.saveNote(dashboardResponse.data.attendance_note);
      preferences
          .saveEmployeeLocation(dashboardResponse.data.employee_location);
      isNoteEnabled = await preferences.getNote();
      isLocationEnabled = await preferences.getEnableLocation();

      final holidayResponse = dashboardResponse.data.holiday;
      final recentAwardResponse = dashboardResponse.data.recentAward;
      event = dashboardResponse.data.recentEvent;
      training = dashboardResponse.data.recentTraining;

      if (holidayResponse != null) {
        bool isAd = await preferences.getEnglishDate();
        DateTime tempDate =
            DateFormat("yyyy-MM-dd").parse(holidayResponse.eventDate);

        NepaliDateTime nepaliDate = tempDate.toNepaliDateTime();
        holiday = Holiday(
            id: holidayResponse.id,
            day: isAd
                ? DateFormat('dd').format(tempDate)
                : NepaliDateFormat('dd').format(nepaliDate),
            month: isAd
                ? DateFormat('MMM').format(tempDate)
                : NepaliDateFormat('MMMM').format(nepaliDate),
            title: holidayResponse.event,
            description: holidayResponse.description,
            dateTime: tempDate,
            isPublicHoliday: holidayResponse.isPublicHoliday);
      } else {
        holiday = null;
      }

      if (recentAwardResponse != null) {
        award = Award(
            award_description: recentAwardResponse.award_description,
            award_name: recentAwardResponse.award_name,
            awarded_by: recentAwardResponse.awarded_by,
            awarded_date: recentAwardResponse.awarded_date,
            employee_name: recentAwardResponse.employee_name,
            gift_description: recentAwardResponse.gift_description,
            gift_item: recentAwardResponse.gift_item,
            id: recentAwardResponse.id,
            image: recentAwardResponse.image,
            awardImage: recentAwardResponse.awardImage,
            reward_code: recentAwardResponse.reward_code);
      } else {
        award = null;
      }

      final startTimeText =
          dashboardResponse.data.officeTime.startTime?.toString().trim() ?? '';
      final endTimeText =
          dashboardResponse.data.officeTime.endTime?.toString().trim() ?? '';

      if (startTimeText.isEmpty || endTimeText.isEmpty) {
        print(
            '⚠️ Skipping notification scheduling because office time is null/empty');
      } else {
        final DateTime? startTime = _parseOfficeTime(startTimeText);
        final DateTime? endTime = _parseOfficeTime(endTimeText);

        if (startTime == null || endTime == null) {
          print(
              '⚠️ Skipping notification scheduling because office time could not be parsed');
        } else {
          try {
            AwesomeNotifications().cancelAllSchedules();
          } catch (e) {
            print('❌ Failed to cancel scheduled notifications: $e');
          }

          for (var shift in dashboardResponse.data.shift_dates) {
            scheduleNewNotification(
                shift,
                "Please check in on time ⏱️⌛️",
                startTime.hour,
                startTime.minute,
                "Almost done with your shift 😄⌛️ Remember to checkout ⏱️",
                endTime.hour,
                endTime.minute);
          }
        }
      }

      checkAD();
      await getFeatures();

      // Pre-cache SSIDs in background for faster check-in
      _preCacheSsidsInBackground();

      return dashboardResponse;
    } else {
      if (response.statusCode == 401) {
        // Do not clear preferences or navigate away here. Let the UI layer
        // handle authentication failures explicitly so logout happens only
        // on user action. Throw a recognizable error that callers already
        // check for (see attendance_bottom_sheet.dart).
        throw "Unauthenticated";
      }

      var errorMessage = responseData['message'];
      print(errorMessage.toString());
      throw errorMessage;
    }
  }

  void makeWeeklyReport(List<dynamic> employeeWeeklyReport) {
    _weeklyReport.clear();
    for (var item in employeeWeeklyReport) {
      if (item != null) {
        double hr = (item['productive_time_in_min'] / 60);

        _weeklyReport.add(hr);
      } else {
        _weeklyReport.add(0);
      }
    }

    barchartValue.clear();
    rawBarGroups.clear();
    showingBarGroups.clear();
    for (int i = 0; i < _weeklyReport.length; i++) {
      barchartValue.add(makeGroupData(i, _weeklyReport[i].toDouble()));
    }

    rawBarGroups.addAll(barchartValue);
    showingBarGroups.addAll(rawBarGroups);

    notifyListeners();
  }

  void updateAttendanceStatus(EmployeeTodayAttendance employeeTodayAttendance) {
    final normalizedCheckIn =
        _normalizeAttendanceTime(employeeTodayAttendance.checkInAt);
    final normalizedCheckOut =
        _normalizeAttendanceTime(employeeTodayAttendance.checkOutAt);
    final allowedBreakMinutes = employeeTodayAttendance.allowedBreakTime < 0
        ? 0
        : employeeTodayAttendance.allowedBreakTime;
    final breakUsedMinutes = employeeTodayAttendance.breakUsedTime < 0
        ? 0
        : employeeTodayAttendance.breakUsedTime;
    final remainingBreakMinutes = employeeTodayAttendance.remainingBreakTime < 0
        ? 0
        : employeeTodayAttendance.remainingBreakTime;

    _attendanceList.update('production-time',
        (value) => calculateProdHour(employeeTodayAttendance.productionTime));
    _attendanceList.update('check-out', (value) => normalizedCheckOut);
    _attendanceList.update('production_hour',
        (value) => calculateHourText(employeeTodayAttendance.productionTime));
    _attendanceList.update(
        'allowed_break_time_minutes', (value) => allowedBreakMinutes);
    _attendanceList.update('break_used_minutes', (value) => breakUsedMinutes);
    _attendanceList.update(
        'remaining_break_time_minutes', (value) => remainingBreakMinutes);
    _attendanceList.update('allowed_break_time',
        (value) => calculateRemainingBreakTimeText(allowedBreakMinutes));
    _attendanceList.update('break_used_time',
        (value) => calculateRemainingBreakTimeText(breakUsedMinutes));
    _attendanceList.update('remaining_break_time',
        (value) => calculateRemainingBreakTimeText(remainingBreakMinutes));
    _attendanceList.update(
        'remaining_break_time_percent',
        (value) => calculateRemainingBreakTimePercent(
            remainingBreakMinutes, allowedBreakMinutes));
    _attendanceList.update('check-in', (value) => normalizedCheckIn);
    _attendanceList.update(
        'is_on_break', (value) => employeeTodayAttendance.isOnBreak);

    notifyListeners();
  }

  String _normalizeAttendanceTime(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return '-';
    }
    return trimmed;
  }

  void updateOverView(Overview overview) {
    _overviewList.update('present', (value) => overview.presentDays.toString());
    _overviewList.update(
        'holiday', (value) => overview.totalHolidays.toString());
    _overviewList.update(
        'leave', (value) => overview.totalLeaveTaken.toString());
    _overviewList.update(
        'request', (value) => overview.totalPendingLeaves.toString());
    _overviewList.update('total_project',
        (value) => overview.total_assigned_projects.toString());
    _overviewList.update(
        'total_task', (value) => overview.total_pending_tasks.toString());
    _overviewList.update(
        'total_awards', (value) => overview.total_awards.toString());
    _overviewList.update(
        'active_training', (value) => overview.active_training.toString());
    _overviewList.update(
        'active_event', (value) => overview.active_event.toString());

    notifyListeners();
  }

  double calculateProdHour(int value) {
    // Calculate percentage: total minutes worked / total working minutes (8 hours * 60 minutes)
    double totalWorkingMinutes = Constant.TOTAL_WORKING_HOUR * 60.0;
    double hr = value / totalWorkingMinutes;

    return hr > 1 ? 1 : hr;
  }

  String calculateHourText(int value) {
    // value is already in minutes, so convert directly to hours and minutes
    int hour = value ~/ 60;
    int minGone = (value % 60).toInt();

    print("$hour hr $minGone min");
    return "$hour hr $minGone min";
  }

  String calculateRemainingBreakTimeText(int value) {
    final hour = value ~/ 60;
    final minGone = value % 60;

    if (hour <= 0) {
      return '$minGone min';
    }

    return '$hour hr $minGone min';
  }

  double calculateRemainingBreakTimePercent(
      int remainingMinutes, int allowedMinutes) {
    if (remainingMinutes <= 0 || allowedMinutes <= 0) {
      return 0.0;
    }

    final percent = remainingMinutes / allowedMinutes;
    return percent > 1 ? 1 : percent;
  }

  void controlFeatures(List<Feature> features) {
    Preferences preferences = Preferences();
    Map<String, String> featureList = <String, String>{};

    for (var feature in features) {
      featureList[feature.key] = feature.status;
    }

    preferences.setFeatures(featureList);
  }

  Future<bool> getCheckInStatus() async {
    try {
      Preferences preferences = Preferences();
      final position = await LocationStatus()
          .determinePosition(await preferences.getWorkSpace());

      locationStatus.update('latitude', (value) => position.latitude);
      locationStatus.update('longitude', (value) => position.longitude);

      if (locationStatus['latitude'] != 0.0 &&
          locationStatus['longitude'] != 0.0) {
        return true;
      } else {
        Future.error(
            'Location is not detected. Please check if location is enabled and try again.');
        return false;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> onSendLocation() async {
    try {
      await getCheckInStatus();
      Preferences preferences = Preferences();
      var uri =
          Uri.parse(await preferences.getAppUrl() + Constant.SEND_LOCATION);

      String token = await preferences.getToken();

      Map<String, String> headers = {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token'
      };

      final response = await http.post(uri, headers: headers, body: {
        'latitude': locationStatus['latitude'].toString(),
        'longitude': locationStatus['longitude'].toString(),
      });

      final responseData = ApiResponseHandler.parseResponse(response);

      if (response.statusCode == 200) {
        return responseData["message"];
      } else {
        if (response.statusCode == 401) {
          throw "Unauthenticated";
        }
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      rethrow;
    }
  }

  String _normalizeWifiValue(String? value) {
    return (value ?? '').trim().replaceAll('"', '').toLowerCase();
  }

  /// Pre-cache SSIDs in background for faster check-in
  void _preCacheSsidsInBackground() {
    try {
      // Fire and forget - fetch SSIDs in background without blocking
      Future(() async {
        try {
          Preferences preferences = Preferences();
          final token = await preferences.getToken();
          final appUrl = await preferences.getAppUrl();
          await _fetchServerSsids(token: token, appUrl: appUrl);
          log('[WiFiAuth] ✅ SSIDs pre-cached in background');
        } catch (e) {
          log('[WiFiAuth] Pre-cache failed: $e');
          // Silently fail - will fetch on demand if needed
        }
      });
    } catch (_) {
      // Ignore errors in background pre-cache
    }
  }

  bool _isMacAddress(String value) {
    return RegExp(r'^[0-9a-f]{2}(:[0-9a-f]{2}){5}$').hasMatch(value);
  }

  /// Matches office WiFi and returns the matched BSSID from server, or null if no match
  String? _findMatchedServerBssid(
    List<dynamic> serverSsids, {
    required String? currentBssid,
    required String? currentSsid,
  }) {
    final bssidNorm = _normalizeWifiValue(currentBssid);
    final ssidNorm = _normalizeWifiValue(currentSsid);
    if (bssidNorm.isEmpty && ssidNorm.isEmpty) return null;

    for (int i = 0; i < serverSsids.length; i++) {
      final item = serverSsids[i];
      if (item is Map) {
        final candidates = [
          item['bssid'],
          item['router_bssid'],
          item['router_mac'],
          item['mac'],
          item['ssid'],
          item['name'],
        ];

        for (final candidate in candidates) {
          final normalizedCandidate =
              _normalizeWifiValue(candidate?.toString());
          if (normalizedCandidate.isEmpty) continue;

          if (bssidNorm.isNotEmpty && normalizedCandidate == bssidNorm) {
            return normalizedCandidate;
          }

          if (!_isMacAddress(normalizedCandidate) &&
              ssidNorm.isNotEmpty &&
              normalizedCandidate == ssidNorm) {
            return normalizedCandidate;
          }
        }
      }
    }

    return null;
  }

  Future<List<dynamic>> _fetchServerSsids({
    required String token,
    required String appUrl,
  }) async {
    // Check if cache is still valid
    if (_cachedServerSsids.isNotEmpty && _ssidCacheTime != null) {
      final cachAge = DateTime.now().difference(_ssidCacheTime!);
      if (cachAge < _ssidCacheDuration) {
        log('[WiFiAuth] ⚡ Cache HIT - reusing ${_cachedServerSsids.length} SSIDs');
        return _cachedServerSsids;
      }
    }

    // Fetch fresh SSID list from server
    final uri = Uri.parse('$appUrl${Constant.ROUTER_SSID_URL}');
    log('[WiFiAuth] 🔄 Cache MISS - fetching fresh SSIDs');
    final response = await TimeoutHttpClient.get(
      uri,
      headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      timeout: const Duration(seconds: 8),
    );

    if (response.statusCode != 200) {
      return [];
    }

    final data = ApiResponseHandler.parseResponse(response);
    List<dynamic> filtered = [];

    if (data is Map && data['data'] is List) {
      filtered = (data['data'] as List)
          .where((s) => s is Map && s['is_active'].toString() == '1')
          .toList();
    } else if (data is List) {
      filtered = data
          .where((s) => s is Map && s['is_active'].toString() == '1')
          .toList();
    }

    // Update cache without logging full response
    _cachedServerSsids = filtered;
    _ssidCacheTime = DateTime.now();

    return filtered;
  }

  Future<Map<String, String>> _resolveAuthorizedWifi({
    required String token,
    required String appUrl,
  }) async {
    final wifiInfo = WifiInfo();
    final wifiInfoResults = await Future.wait([
      wifiInfo.wifiBSSID(),
      wifiInfo.wifiname(),
    ]);

    final currentBssid = wifiInfoResults[0] as String?;
    final currentSsid = wifiInfoResults[1] as String?;

    final normalizedBssid = _normalizeWifiValue(currentBssid);
    final normalizedSsid = _normalizeWifiValue(currentSsid);
    debugPrint(
      '[WiFiAuth] Current WiFi BSSID: ${normalizedBssid.isEmpty ? '(empty)' : normalizedBssid}, SSID: ${normalizedSsid.isEmpty ? '(empty)' : normalizedSsid}',
    );
    if (normalizedBssid.isEmpty && normalizedSsid.isEmpty) {
      throw 'Unable to read current WiFi details. Please reconnect and try again.';
    }

    final serverSsids = await _fetchServerSsids(token: token, appUrl: appUrl);
    if (serverSsids.isEmpty) {
      throw 'Could not validate office WiFi at the moment. Please try again.';
    }

    // Find the matched server BSSID
    final matchedServerBssid = _findMatchedServerBssid(
      serverSsids,
      currentBssid: currentBssid,
      currentSsid: currentSsid,
    );

    if (matchedServerBssid == null) {
      throw 'WiFi network is not authorized for attendance. Please connect to the correct network.';
    }

    return {
      'ssid':
          matchedServerBssid, // Send the matched BSSID from server as router_ssid
      'bssid': normalizedBssid, // Send the current device BSSID as router_bssid
    };
  }

  Future<AttendanceStatusResponse> checkInAttendance() async {
    try {
      if (_isCheckInBlockedByBreak(explicitStatusType: 'checkIn')) {
        throw _kBreakExceededCheckInMessage;
      }

      Preferences preferences = Preferences();
      final appUrl = await preferences.getAppUrl();
      var uri = Uri.parse(appUrl + Constant.ATTENDANCE_URL);

      String token = await preferences.getToken();

      // Parallelize: fetch WiFi auth and location simultaneously
      final results = await Future.wait([
        _resolveAuthorizedWifi(token: token, appUrl: appUrl),
        Future.value(null), // Placeholder for location (already available)
      ]);
      final wifi = results[0] as Map<String, String>;

      Map<String, String> headers = {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token'
      };

      final response = await http.post(uri, headers: headers, body: {
        'attendance_type': 'wifi',
        'latitude': (locationStatus['latitude'] ?? 0.0).toString(),
        'longitude': (locationStatus['longitude'] ?? 0.0).toString(),
        'router_ssid': wifi['ssid'] ?? '',
        'router_bssid': wifi['bssid'] ?? '',
        'identifier': '',
        'attendance_status_type': 'checkIn',
        'note': '',
      });

      final responseData = ApiResponseHandler.parseResponse(response);

      if (response.statusCode == 200) {
        final status = responseData['status'] ?? true;
        final message = responseData['message']?.toString() ?? 'Checked in';

        // Fire-and-forget dashboard refresh
        if (status == true) {
          Future.microtask(() => getDashboard());
        }

        return AttendanceStatusResponse(
          status: status,
          message: message,
          statusCode: responseData['status_code'] ?? 200,
          data: AttendanceStatus(
            checkInAt: _attendanceList['check-in'] ?? '-',
            checkOutAt: _attendanceList['check-out'] ?? '-',
            productiveTimeInMin: 0,
          ),
        );
      } else {
        if (response.statusCode == 401) {
          throw "Unauthenticated";
        }
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      throw _userFriendlyAttendanceError(e);
    }
  }

  DateTime? _parseOfficeTime(String value) {
    try {
      return DateFormat("hh:mm a").parse(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> scheduleNewNotification(
      String date,
      String startMessage,
      int startHr,
      int startMin,
      String endMessage,
      int endHr,
      int endMin) async {
    final convertedDate = new DateFormat('yyyy-MM-dd').parse(date);

    try {
      await AwesomeNotifications().createNotification(
          content: NotificationContent(
              id: Random.Random().nextInt(1000000),
              // -1 is replaced by a random number
              channelKey: 'digital_hr_channel',
              title: "Hello There",
              body: startMessage,
              //'asset://assets/images/balloons-in-sky.jpg',
              notificationLayout: NotificationLayout.Default,
              payload: {'notificationId': '1234567890'}),
          actionButtons: [
            NotificationActionButton(
                key: 'REDIRECT', label: 'Open', actionType: ActionType.Default),
            NotificationActionButton(
                key: 'DISMISS',
                label: 'Dismiss',
                actionType: ActionType.DismissAction,
                isDangerousOption: true)
          ],
          schedule: NotificationCalendar.fromDate(
              date: DateTime(convertedDate.year, convertedDate.month,
                  convertedDate.day, startHr, startMin - 15)));

      await AwesomeNotifications().createNotification(
          content: NotificationContent(
              id: Random.Random().nextInt(1000000),
              // -1 is replaced by a random number
              channelKey: 'digital_hr_channel',
              title: "Hello There",
              body: endMessage,
              //'asset://assets/images/balloons-in-sky.jpg',
              notificationLayout: NotificationLayout.Default,
              payload: {'notificationId': '1234567890'}),
          actionButtons: [
            NotificationActionButton(
                key: 'REDIRECT', label: 'Open', actionType: ActionType.Default),
            NotificationActionButton(
                key: 'DISMISS',
                label: 'Dismiss',
                actionType: ActionType.DismissAction,
                isDangerousOption: true)
          ],
          schedule: NotificationCalendar.fromDate(
              date: DateTime(convertedDate.year, convertedDate.month,
                  convertedDate.day, endHr, endMin - 15)));
    } catch (e) {
      print('❌ Failed to create scheduled notifications: $e');
    }
  }

  Future<AttendanceStatusResponse> checkOutAttendance() async {
    try {
      Preferences preferences = Preferences();
      final appUrl = await preferences.getAppUrl();
      var uri = Uri.parse(appUrl + Constant.ATTENDANCE_URL);

      String token = await preferences.getToken();

      // Parallelize: fetch WiFi auth and location simultaneously
      final results = await Future.wait([
        _resolveAuthorizedWifi(token: token, appUrl: appUrl),
        Future.value(null), // Placeholder for location (already available)
      ]);
      final wifi = results[0] as Map<String, String>;

      Map<String, String> headers = {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token'
      };

      final response = await http.post(uri, headers: headers, body: {
        'attendance_type': 'wifi',
        'latitude': (locationStatus['latitude'] ?? 0.0).toString(),
        'longitude': (locationStatus['longitude'] ?? 0.0).toString(),
        'router_ssid': wifi['ssid'] ?? '',
        'router_bssid': wifi['bssid'] ?? '',
        'identifier': '',
        'attendance_status_type': 'checkOut',
        'note': '',
      });
      debugPrint(response.body.toString());

      final responseData = ApiResponseHandler.parseResponse(response);

      if (response.statusCode == 200) {
        final status = responseData['status'] ?? true;
        final message = responseData['message']?.toString() ?? 'Checked out';

        // Fire-and-forget dashboard refresh
        if (status == true) {
          Future.microtask(() => getDashboard());
        }

        return AttendanceStatusResponse(
          status: status,
          message: message,
          statusCode: responseData['status_code'] ?? 200,
          data: AttendanceStatus(
            checkInAt: _attendanceList['check-in'] ?? '-',
            checkOutAt: _attendanceList['check-out'] ?? '-',
            productiveTimeInMin: 0,
          ),
        );
      } else {
        if (response.statusCode == 401) {
          throw "Unauthenticated";
        }
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      throw _userFriendlyAttendanceError(e);
    }
  }

  Future<AttendanceStatusResponse> verifyAttendanceApi(String type, String note,
      {String attendanceStatus = "", String identifier = ""}) async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();
    final http.Client client = await LoggingMiddleware.create();

    try {
      http.Response response;

      if (type == "wifi") {
        final appUrl = await preferences.getAppUrl();
        final uri = Uri.parse(appUrl + Constant.ATTENDANCE_URL);
        final wifi = await _resolveAuthorizedWifi(token: token, appUrl: appUrl);
        final statusType =
            attendanceStatus.isEmpty ? 'checkIn' : attendanceStatus;

        if (_isCheckInBlockedByBreak(explicitStatusType: statusType)) {
          throw _kBreakExceededCheckInMessage;
        }

        response = await client.post(uri, headers: {
          'Accept': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        }, body: {
          'attendance_type': 'wifi',
          'latitude': (locationStatus['latitude'] ?? 0.0).toString(),
          'longitude': (locationStatus['longitude'] ?? 0.0).toString(),
          'router_ssid': wifi['ssid'] ?? '',
          'router_bssid': wifi['bssid'] ?? '',
          'identifier': '',
          'attendance_status_type': statusType,
          'note': note,
        });

        log(response.body.toString());

        final responseData = ApiResponseHandler.parseResponse(response);

        if (response.statusCode == 200) {
          final status = responseData['status'] ?? true;
          final message =
              responseData['message']?.toString() ?? 'Attendance recorded';

          // Refresh dashboard to get updated check-in/check-out times
          if (status == true) {
            Future.microtask(() async {
              try {
                await getDashboard();
              } catch (_) {}
            });
          }

          noteController.clear();
          return AttendanceStatusResponse(
            status: status,
            message: message,
            statusCode: responseData['status_code'] ?? 200,
            data: AttendanceStatus(
              checkInAt: _attendanceList['check-in'] ?? '-',
              checkOutAt: _attendanceList['check-out'] ?? '-',
              productiveTimeInMin: 0,
            ),
          );
        } else {
          if (response.statusCode == 401) {
            throw "Unauthenticated";
          }
          var errorMessage = responseData['message'];
          throw errorMessage;
        }
      } else {
        // Non-WiFi types (QR, NFC, etc.) use the original attendance endpoint
        if (_isCheckInBlockedByBreak()) {
          throw _kBreakExceededCheckInMessage;
        }

        final uri =
            Uri.parse(await preferences.getAppUrl() + Constant.ATTENDANCE_URL);
        print(identifier);

        response = await client.post(uri, headers: {
          'Accept': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        }, body: {
          'attendance_type': type,
          'latitude': '',
          'longitude': '',
          'router_bssid': '',
          'identifier': identifier,
          'attendance_status_type': '',
          'note': note,
        });

        log(response.body.toString());

        final responseData = ApiResponseHandler.parseResponse(response);

        if (response.statusCode == 200) {
          final attendanceResponse =
              AttendanceStatusResponse.fromJson(responseData);

          updateAttendanceStatus(EmployeeTodayAttendance(
              checkInAt: attendanceResponse.data.checkInAt,
              checkOutAt: attendanceResponse.data.checkOutAt,
              productionTime: attendanceResponse.data.productiveTimeInMin,
              allowedBreakTime:
                  _attendanceMinutes('allowed_break_time_minutes'),
              breakUsedTime: _attendanceMinutes('break_used_minutes'),
              remainingBreakTime:
                  _attendanceMinutes('remaining_break_time_minutes'),
              isOnBreak: _attendanceList['is_on_break'] == true));
          noteController.clear();
          return attendanceResponse;
        } else {
          if (response.statusCode == 401) {
            throw "Unauthenticated";
          }
          var errorMessage = responseData['message'];
          throw errorMessage;
        }
      }
    } catch (e) {
      throw _userFriendlyAttendanceError(e);
    } finally {
      client.close();
    }
  }

  Future<String> submitBreakRequest(String reason) async {
    final checkIn = (_attendanceList['check-in'] ?? '-').toString();
    final checkOut = (_attendanceList['check-out'] ?? '-').toString();
    final isAttendanceActive = checkIn != '-' && checkOut == '-';
    final isOnBreak = _attendanceList['is_on_break'] == true;

    if (!isAttendanceActive && !isOnBreak) {
      throw 'You are not checked in yet. Please check in before requesting a break.';
    }

    Preferences preferences = Preferences();
    final appUrl = await preferences.getAppUrl();
    final uri = Uri.parse(appUrl + Constant.BREAK_REQUEST_URL);
    final token = await preferences.getToken();

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'reason': reason,
      }),
    );

    final responseData = ApiResponseHandler.parseResponse(response);

    if (response.statusCode == 200) {
      final message = responseData['message']?.toString();
      return message?.isNotEmpty == true ? message! : 'Break request submitted';
    }

    if (response.statusCode == 401) {
      throw 'Unauthenticated';
    }

    throw responseData['message']?.toString() ??
        'Failed to submit break request';
  }

  final Color leftBarColor = HexColor("#FFFFFF");

  final double width = 15;

  BarChartGroupData makeGroupData(int x, double y1) {
    return BarChartGroupData(barsSpace: 4, x: x, barRods: [
      BarChartRodData(
        toY: y1,
        color: leftBarColor,
        width: width,
      ),
    ]);
  }
}
