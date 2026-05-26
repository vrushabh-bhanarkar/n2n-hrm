import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class WifiPollingService {
  static const Duration _pollingInterval = Duration(seconds: 12);
  static const Duration _breakTimeThreshold = Duration(minutes: 15);

  final SharedPreferences preferences;
  final String baseUrl;
  final String token;

  Timer? _pollingTimer;
  DateTime? _lastDisconnectTime;

  WifiPollingService({
    required this.preferences,
    required this.baseUrl,
    required this.token,
  });

  void startPolling() {
    if (_pollingTimer != null) return;

    _restoreDisconnectTime();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) => _checkAndSync());
    _checkAndSync();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _checkAndSync() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isWifiConnected =
          connectivityResult.contains(ConnectivityResult.wifi);

      String currentBssid = '';
      String currentSsid = '';

      if (isWifiConnected) {
        try {
          currentBssid =
              _normalizeWifiValue(await NetworkInfo().getWifiBSSID());
          currentSsid = _normalizeWifiValue(await NetworkInfo().getWifiName());
        } catch (e) {
          log('[WifiPolling] WiFi info read error: $e');
        }
      }

      final isOfficeWifi =
          await _isConnectedToOfficeWifi(currentBssid, currentSsid);
      final attendanceStatus = await _getAttendanceStatus();

      if (isOfficeWifi && attendanceStatus == 'none') {
        await _autoCheckIn();
      }

      if (!isOfficeWifi) {
        await _handleDisconnect(attendanceStatus);
      } else if (_lastDisconnectTime != null) {
        await _handleReconnect(attendanceStatus);
        _lastDisconnectTime = null;
        await preferences.setString(Preferences.WIFI_LAST_DISCONNECT_TIME, '');
      }

      await _postWifiStatus(
        status: isOfficeWifi ? 'connected' : 'disconnected',
        bssid: currentBssid,
        ssid: currentSsid,
      );
    } catch (e) {
      log('[WifiPolling] Error in _checkAndSync: $e');
    }
  }

  String _normalizeWifiValue(String? value) {
    return (value ?? '').trim().replaceAll('"', '').toLowerCase();
  }

  bool _isMacAddress(String value) {
    return RegExp(r'^[0-9a-f]{2}(:[0-9a-f]{2}){5}$').hasMatch(value);
  }

  bool _isRouterActive(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'active';
  }

  List<dynamic> _routerCandidates(Map item) {
    return [
      item['bssid'],
      item['router_bssid'],
      item['router_mac'],
      item['mac'],
      item['ssid'],
      item['name'],
    ];
  }

  Future<bool> _isConnectedToOfficeWifi(String bssid, String ssid) async {
    try {
      final cachedSsids = preferences.getString(Preferences.WIFI_SERVER_SSIDS);
      List<dynamic> serverSsids = [];

      if (cachedSsids != null && cachedSsids.isNotEmpty) {
        try {
          serverSsids = jsonDecode(cachedSsids);
        } catch (_) {
          serverSsids = [];
        }
      }

      if (serverSsids.isEmpty) {
        serverSsids = await _fetchServerSsids();
        if (serverSsids.isNotEmpty) {
          await preferences.setString(
            Preferences.WIFI_SERVER_SSIDS,
            jsonEncode(serverSsids),
          );
        }
      }

      if (serverSsids.isEmpty) return false;

      for (final item in serverSsids) {
        if (item is! Map) continue;

        final candidates = _routerCandidates(item);
        for (final candidate in candidates) {
          final value = _normalizeWifiValue(candidate?.toString());
          if (value.isEmpty) continue;

          if (bssid.isNotEmpty && value == bssid) {
            return true;
          }

          if (!_isMacAddress(value) && ssid.isNotEmpty && value == ssid) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      log('[WifiPolling] Error checking office WiFi: $e');
      return false;
    }
  }

  Future<List<dynamic>> _fetchServerSsids() async {
    try {
      final uri = Uri.parse('$baseUrl${Constant.ROUTER_SSID_URL}');
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return [];
      }

      final payload = jsonDecode(response.body);
      if (payload is Map && payload['data'] is List) {
        return (payload['data'] as List)
            .where((s) =>
                s is Map &&
                (_isRouterActive(s['is_active']) || s['is_active'] == null))
            .toList();
      }

      if (payload is List) {
        return payload
            .where((s) =>
                s is Map &&
                (_isRouterActive(s['is_active']) || s['is_active'] == null))
            .toList();
      }

      return [];
    } catch (e) {
      log('[WifiPolling] Error fetching server SSIDs: $e');
      return [];
    }
  }

  Future<String> _getAttendanceStatus() async {
    try {
      final uri =
          Uri.parse('$baseUrl${Constant.EMPLOYEE_ATTENDANCE_STATUS_URL}');
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return _getCachedAttendanceStatus();
      }

      final payload = jsonDecode(response.body);
      final status = _mapAttendanceStatus(payload);

      await preferences.setString(Preferences.WIFI_SESSION_STATUS, status);
      return status;
    } catch (e) {
      log('[WifiPolling] Error getting attendance status: $e');
      return _getCachedAttendanceStatus();
    }
  }

  String _getCachedAttendanceStatus() {
    return preferences.getString(Preferences.WIFI_SESSION_STATUS) ?? 'none';
  }

  Future<void> _autoCheckIn() async {
    try {
      final uri = Uri.parse('$baseUrl${Constant.CHECK_IN_URL}');
      final response = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json; charset=UTF-8',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': preferences.getDouble('last_latitude') ?? 0.0,
              'longitude': preferences.getDouble('last_longitude') ?? 0.0,
              'auto_checkin': true,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        await preferences.setString(
            Preferences.WIFI_SESSION_STATUS, 'checked_in');
        log('[WifiPolling] Auto check-in successful');
      }
    } catch (e) {
      log('[WifiPolling] Error during auto check-in: $e');
    }
  }

  Future<void> _autoCheckOut() async {
    try {
      final uri = Uri.parse('$baseUrl${Constant.ATTENDANCE_URL}');
      final routerSsid =
          preferences.getString(Preferences.WIFI_OFFICE_SSID) ?? '';
      final routerBssid =
          preferences.getString(Preferences.WIFI_OFFICE_BSSID) ?? '';
      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: {
          'attendance_type': 'wifi',
          'latitude':
              (preferences.getDouble('last_latitude') ?? 0.0).toString(),
          'longitude':
              (preferences.getDouble('last_longitude') ?? 0.0).toString(),
          'router_ssid': routerSsid,
          'router_bssid': routerBssid,
          'identifier': '',
          'attendance_status_type': 'checkOut',
          'note': '',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        await preferences.setString(
            Preferences.WIFI_SESSION_STATUS, 'checked_out');
        await preferences.setString(Preferences.WIFI_LAST_DISCONNECT_TIME, '');
        log('[WifiPolling] Auto check-out successful');
      } else {
        log('[WifiPolling] Auto check-out failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log('[WifiPolling] Error during auto check-out: $e');
    }
  }

  Future<void> _handleDisconnect(String attendanceStatus) async {
    try {
      final persistedDisconnect =
          preferences.getString(Preferences.WIFI_LAST_DISCONNECT_TIME) ?? '';
      if (persistedDisconnect.isNotEmpty) {
        _lastDisconnectTime ??= DateTime.tryParse(persistedDisconnect);
      }

      _lastDisconnectTime ??= DateTime.now();
      await preferences.setString(
        Preferences.WIFI_LAST_DISCONNECT_TIME,
        _lastDisconnectTime!.toIso8601String(),
      );

      final elapsed = DateTime.now().difference(_lastDisconnectTime!);

      if (elapsed >= _breakTimeThreshold &&
          (attendanceStatus == 'checked_in' ||
              attendanceStatus == 'on_break')) {
        await _autoCheckOut();
      }
    } catch (e) {
      log('[WifiPolling] Error handling disconnect: $e');
    }
  }

  Future<void> _handleReconnect(String attendanceStatus) async {
    try {
      if (attendanceStatus == 'on_break') {
        await _updateBreakLog('reconnected');
      }
    } catch (e) {
      log('[WifiPolling] Error handling reconnect: $e');
    }
  }

  Future<void> _postWifiStatus({
    required String status,
    required String? bssid,
    required String? ssid,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl${Constant.WIFI_STATUS_URL}');
      final response = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json; charset=UTF-8',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'status': status,
              'router_bssid': bssid ?? '',
              'ssid': ssid ?? '',
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        log('[WifiPolling] WiFi status post failed: ${response.statusCode}');
      }
    } catch (e) {
      log('[WifiPolling] Error posting WiFi status: $e');
    }
  }

  Future<void> _updateBreakLog(String event) async {
    try {
      final currentLog =
          preferences.getString(Preferences.WIFI_BREAK_LOG) ?? '[]';
      final List<dynamic> logs = jsonDecode(currentLog);

      logs.add({
        'event': event,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await preferences.setString(Preferences.WIFI_BREAK_LOG, jsonEncode(logs));
    } catch (e) {
      log('[WifiPolling] Error updating break log: $e');
    }
  }

  void _restoreDisconnectTime() {
    try {
      final persistedDisconnect =
          preferences.getString(Preferences.WIFI_LAST_DISCONNECT_TIME) ?? '';
      if (persistedDisconnect.isNotEmpty) {
        _lastDisconnectTime = DateTime.tryParse(persistedDisconnect);
      }
    } catch (e) {
      log('[WifiPolling] Error restoring disconnect time: $e');
    }
  }

  String _mapAttendanceStatus(dynamic payload) {
    if (payload is! Map) return 'none';

    final data = payload['data'];
    if (data is! Map) return 'none';

    final attendance = data['employee_today_attendance'];
    final attendanceMap = attendance is Map ? attendance : <String, dynamic>{};

    final checkedIn = data['checked_in'] == true ||
        attendanceMap['check_in_at'] != null ||
        data['check_in_at'] != null;
    final checkedOut = data['checked_out'] == true ||
        attendanceMap['check_out_at'] != null ||
        data['check_out_at'] != null;
    final onBreak =
        data['is_on_break'] == true || attendanceMap['is_on_break'] == true;

    if (checkedIn && !checkedOut) {
      return onBreak ? 'on_break' : 'checked_in';
    }

    if (checkedOut) return 'checked_out';

    return 'none';
  }
}
