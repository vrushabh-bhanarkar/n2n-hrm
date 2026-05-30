import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/office_geofence.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const String _kWifiAttendanceChannelId = 'wifi_attendance_channel';
const String _kWifiAttendanceChannelName = 'WiFi Auto Attendance';
const int _kForegroundNotifId = 888;
const Duration _kAutoCheckInLocationFreshness = Duration(minutes: 10);

String _normalizeWifiValue(String? value) {
  return (value ?? '').trim().replaceAll('"', '').toLowerCase();
}

bool _isPlaceholderBssid(String value) {
  return value.isEmpty || value == '02:00:00:00:00:00';
}

bool _isUnknownSsid(String value) {
  return value.isEmpty ||
      value == '<unknown ssid>' ||
      value == 'unknown ssid' ||
      value == '0x';
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

bool _matchesOfficeWifi(
  List<dynamic> serverSsids, {
  required String? currentBssid,
  required String? currentSsid,
}) {
  final bssidNorm = _normalizeWifiValue(currentBssid);
  final ssidNorm = _normalizeWifiValue(currentSsid);
  if (bssidNorm.isEmpty && ssidNorm.isEmpty) return false;

  for (final item in serverSsids) {
    if (item is Map) {
      final candidates = _routerCandidates(item);

      for (final candidate in candidates) {
        final value = _normalizeWifiValue(candidate?.toString());
        if (value.isEmpty) continue;

        if (bssidNorm.isNotEmpty && value == bssidNorm) {
          return true;
        }
        if (!_isMacAddress(value) && ssidNorm.isNotEmpty && value == ssidNorm) {
          return true;
        }
      }
    } else {
      final value = _normalizeWifiValue(item.toString());
      if (value.isEmpty) continue;

      if (bssidNorm.isNotEmpty && value == bssidNorm) {
        return true;
      }
      if (!_isMacAddress(value) && ssidNorm.isNotEmpty && value == ssidNorm) {
        return true;
      }
    }
  }

  return false;
}

Future<bool> _hasNetworkConnection() async {
  try {
    final connectivityResults = await Connectivity().checkConnectivity();
    return !connectivityResults.contains(ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}

Future<bool> _hasRecentLocationFix(SharedPreferences prefs) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );

    if (!OfficeGeofence.isAcceptableOfficePosition(position)) {
      await prefs.remove(Preferences.WIFI_APPROVED_LOCATION_LAT);
      await prefs.remove(Preferences.WIFI_APPROVED_LOCATION_LONG);
      await prefs.remove(Preferences.WIFI_APPROVED_LOCATION_ACCURACY);
      await prefs.remove(Preferences.WIFI_APPROVED_LOCATION_UPDATE_MS);
      return false;
    }

    await prefs.setDouble(
      Preferences.WIFI_APPROVED_LOCATION_LAT,
      position.latitude,
    );
    await prefs.setDouble(
      Preferences.WIFI_APPROVED_LOCATION_LONG,
      position.longitude,
    );
    await prefs.setDouble(
      Preferences.WIFI_APPROVED_LOCATION_ACCURACY,
      position.accuracy,
    );
    await prefs.setInt(
      Preferences.WIFI_APPROVED_LOCATION_UPDATE_MS,
      DateTime.now().millisecondsSinceEpoch,
    );

    return true;
  } catch (_) {
    return false;
  }
}

Future<List<dynamic>> _fetchAndCacheServerSsids(
  SharedPreferences prefs,
  String token,
  String appUrl,
) async {
  try {
    if (!await _hasNetworkConnection()) {
      return [];
    }

    final uri = Uri.parse('$appUrl${Constant.ROUTER_SSID_URL}');
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      return [];
    }

    final payload = jsonDecode(response.body);
    List<dynamic> filtered = [];
    if (payload is Map && payload['data'] is List) {
      filtered = (payload['data'] as List)
          .where((s) =>
              s is Map &&
              (_isRouterActive(s['is_active']) || s['is_active'] == null))
          .toList();
    } else if (payload is List) {
      filtered = payload
          .where((s) =>
              s is Map &&
              (_isRouterActive(s['is_active']) || s['is_active'] == null))
          .toList();
    }

    await prefs.setString(Preferences.WIFI_SERVER_SSIDS, jsonEncode(filtered));
    return filtered;
  } catch (e) {
    log('[WifiAttendance] fetch SSID error: $e');
    return [];
  }
}

Map<String, String?> _extractBackendNotification(dynamic payload) {
  String? pickString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  if (payload is! Map) return {'title': null, 'content': null};

  final data = payload['data'];

  final title = pickString(payload['notification_title']) ??
      pickString(payload['title']) ??
      (data is Map
          ? (pickString(data['notification_title']) ?? pickString(data['title']))
          : null);

  final content = pickString(payload['notification_message']) ??
      pickString(payload['message']) ??
      pickString(payload['notification']) ??
      pickString(payload['status_message']) ??
      (data is Map
          ? (pickString(data['notification_message']) ??
              pickString(data['message']) ??
              pickString(data['notification']) ??
              pickString(data['status_message']))
          : null);

  return {
    'title': title,
    'content': content,
  };
}

Future<Map<String, String?>> _postWifiStatus({
  required String token,
  required String appUrl,
  required String status,
  required String routerBssid,
  required String currentSsid,
}) async {
  try {
    final uri = Uri.parse('$appUrl${Constant.WIFI_STATUS_URL}');
    final body = jsonEncode({
      'status': status,
      'router_bssid': routerBssid,
      'ssid': currentSsid,
    });

    log('[WifiAttendance] 📮 Sending wifi-status to $uri\n   Payload: $body');
    final response = await http
        .post(
          uri,
          headers: {
            'Accept': 'application/json; charset=UTF-8',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final message = _extractApiMessage(response.body);
      log('[WifiAttendance] ✅ wifi-status success: 200 - $message (status=$status)');
      if (_looksLikeJson(response.body)) {
        final payload = jsonDecode(response.body);
        return _extractBackendNotification(payload);
      }
    } else {
      final message = _extractApiMessage(response.body);
      log('[WifiAttendance] ❌ wifi-status failed: ${response.statusCode} - $message (status=$status, bssid=$routerBssid)');
    }
  } on http.ClientException catch (e) {
    log('[WifiAttendance] ❌ wifi-status network error: $e');
  } on TimeoutException {
    log('[WifiAttendance] ⏱️ wifi-status timeout');
  } catch (e) {
    log('[WifiAttendance] ❌ wifi-status unexpected error: $e');
  }

  return {'title': null, 'content': null};
}

String _mapAttendanceStatus(dynamic payload) {
  if (payload is! Map) return 'none';
  final data = payload['data'] is Map ? payload['data'] as Map : payload;

  final rawStatus =
      data['attendance_status'] ?? data['status'] ?? data['session_status'];
  final normalized = _normalizeWifiValue(rawStatus?.toString());
  if (normalized == 'checked_in' ||
      normalized == 'check_in' ||
      normalized == 'checkedin') {
    return data['is_on_break'] == true ? 'on_break' : 'checked_in';
  }
  if (normalized == 'checked_out' ||
      normalized == 'check_out' ||
      normalized == 'checkedout') {
    return 'checked_out';
  }
  if (normalized == 'on_break' || normalized == 'break') {
    return 'on_break';
  }

  final checkedIn = data['checked_in'] == true || data['check_in_at'] != null;
  final checkedOut =
      data['checked_out'] == true || data['check_out_at'] != null;
  final onBreak = data['is_on_break'] == true;

  if (checkedIn && !checkedOut) {
    return onBreak ? 'on_break' : 'checked_in';
  }
  if (checkedOut) return 'checked_out';
  return 'none';
}

bool _looksLikeJson(String body) {
  final trimmed = body.trimLeft();
  return trimmed.startsWith('{') || trimmed.startsWith('[');
}

String _truncateForLog(String value, {int max = 200}) {
  if (value.length <= max) return value;
  return '${value.substring(0, max)}...';
}

String _extractApiMessage(String body) {
  if (!_looksLikeJson(body)) {
    return _truncateForLog(body);
  }

  try {
    final payload = jsonDecode(body);
    if (payload is Map) {
      final message = payload['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
  } catch (_) {
    // Fall back to truncated raw body.
  }

  return _truncateForLog(body);
}

Future<String> _fetchAttendanceStatus(
  SharedPreferences prefs, {
  required String token,
  required String appUrl,
}) async {
  try {
    final uri = Uri.parse('$appUrl${Constant.EMPLOYEE_ATTENDANCE_STATUS_URL}');
    log('[WifiAttendance] 🔍 Fetching attendance status from: $uri');
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 12));

    log('[WifiAttendance] 📡 Attendance-status response: ${response.statusCode} - ${_truncateForLog(response.body)}');
    if (response.statusCode != 200 || !_looksLikeJson(response.body)) {
      final cached = prefs.getString(Preferences.WIFI_SESSION_STATUS) ?? 'none';
      log('[WifiAttendance] ⚠️ Invalid attendance-status response, using cached: $cached');
      return cached;
    }

    final payload = jsonDecode(response.body);
    final mapped = _mapAttendanceStatus(payload);
    await prefs.setString(Preferences.WIFI_SESSION_STATUS, mapped);
    log('[WifiAttendance] ✅ Attendance-status mapped to: $mapped');
    return mapped;
  } on http.ClientException catch (e) {
    log('[WifiAttendance] ❌ attendance-status network error: $e');
    return prefs.getString(Preferences.WIFI_SESSION_STATUS) ?? 'none';
  } on TimeoutException {
    log('[WifiAttendance] ⏱️ attendance-status timeout');
    return prefs.getString(Preferences.WIFI_SESSION_STATUS) ?? 'none';
  } catch (e) {
    log('[WifiAttendance] ❌ attendance-status error: $e');
    return prefs.getString(Preferences.WIFI_SESSION_STATUS) ?? 'none';
  }
}

Future<bool> _autoCheckIn(
  SharedPreferences prefs, {
  required String token,
  required String appUrl,
}) async {
  try {
    if (!await _hasRecentLocationFix(prefs)) {
      log('[WifiAttendance] ⏭️ Skipping auto check-in: location fix is stale or unavailable');
      return false;
    }

    log('[WifiAttendance] 🔄 Attempting auto check-in to $appUrl${Constant.CHECK_IN_URL}');
    final uri = Uri.parse('$appUrl${Constant.CHECK_IN_URL}');
    final response = await http
        .post(
          uri,
          headers: {
            'Accept': 'application/json; charset=UTF-8',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'auto_checkin': true,
            'latitude': prefs.getDouble(Preferences.WIFI_APPROVED_LOCATION_LAT) ?? 0.0,
            'longitude': prefs.getDouble(Preferences.WIFI_APPROVED_LOCATION_LONG) ?? 0.0,
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      await prefs.setString(Preferences.WIFI_SESSION_STATUS, 'checked_in');
      log('[WifiAttendance] ✅ auto check-in success: ${response.statusCode}');
      return true;
    } else {
      log('[WifiAttendance] ❌ auto check-in failed: ${response.statusCode} - ${response.body}');
      return false;
    }
  } on http.ClientException catch (e) {
    log('[WifiAttendance] ❌ auto check-in network error: $e');
  } on TimeoutException {
    log('[WifiAttendance] ⏱️ auto check-in timeout');
  } catch (e) {
    log('[WifiAttendance] ❌ auto check-in error: $e');
  }

  return false;
}

bool _shouldAttemptAutoCheckIn(String attendanceStatus) {
  // `checked_out` can happen after an auto checkout while user is still on office WiFi.
  // Allow re-checkin attempt so approved-break flows do not stay stuck until manual action.
  return attendanceStatus == 'none' || attendanceStatus == 'checked_out';
}

Future<void> _autoCheckOut(
  SharedPreferences prefs, {
  required String token,
  required String appUrl,
}) async {
  try {
    final lastCheckoutAtText =
        prefs.getString(Preferences.WIFI_LAST_CHECKOUT_TIME) ?? '';
    if (lastCheckoutAtText.isNotEmpty) {
      final lastCheckoutAt = DateTime.tryParse(lastCheckoutAtText);
      if (lastCheckoutAt != null &&
          DateTime.now().difference(lastCheckoutAt) <
              const Duration(minutes: 2)) {
        log('[WifiAttendance] ⏭️ Skipping auto check-out: recent checkout already sent at $lastCheckoutAtText');
        return;
      }
    }

    log('[WifiAttendance] 🔄 Attempting auto check-out to $appUrl${Constant.CHECK_OUT_URL}');
    final uri = Uri.parse('$appUrl${Constant.CHECK_OUT_URL}');
    final response = await http
        .post(
          uri,
          headers: {
            'Accept': 'application/json; charset=UTF-8',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'auto_checkout': true,
            'latitude': prefs.getDouble('last_latitude') ?? 0.0,
            'longitude': prefs.getDouble('last_longitude') ?? 0.0,
            'break_reason': 'WiFi disconnection exceeded threshold',
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      await prefs.setString(Preferences.WIFI_SESSION_STATUS, 'checked_out');
      await prefs.setString(
        Preferences.WIFI_LAST_CHECKOUT_TIME,
        DateTime.now().toIso8601String(),
      );
      log('[WifiAttendance] ✅ auto check-out success: ${response.statusCode}');
    } else {
      log('[WifiAttendance] ❌ auto check-out failed: ${response.statusCode} - ${response.body}');
    }
  } on http.ClientException catch (e) {
    log('[WifiAttendance] ❌ auto check-out network error: $e');
  } on TimeoutException {
    log('[WifiAttendance] ⏱️ auto check-out timeout');
  } catch (e) {
    log('[WifiAttendance] ❌ auto check-out error: $e');
  }
}

@pragma('vm:entry-point')
Future<void> wifiAttendanceServiceMain(ServiceInstance service) async {
  Timer? periodicTimer;
  Timer? debounceTimer;
  bool isChecking = false;
  DateTime? lastDisconnectedAt;
  DateTime? lastAutoCheckInAttemptAt;
  String? lastForegroundNotificationTitle;
  String? lastForegroundNotificationContent;

  Future<void> checkAndSyncWifiStatus() async {
    if (isChecking) return;
    isChecking = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final enabled = prefs.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;
      if (!enabled) {
        log('[WifiAttendance] polling skipped: wifi auto disabled');
        return;
      }

      final token = prefs.getString('user_token') ?? '';
      if (token.isEmpty) {
        log('[WifiAttendance] polling skipped: empty auth token');
        return;
      }

      final appUrl = prefs.getString('app_url')?.isNotEmpty == true
          ? prefs.getString('app_url')!
          : Constant.appUrl;

      List<dynamic> serverSsids;
      try {
        serverSsids =
            jsonDecode(prefs.getString(Preferences.WIFI_SERVER_SSIDS) ?? '[]');
      } catch (_) {
        serverSsids = [];
      }

      if (serverSsids.isEmpty) {
        serverSsids = await _fetchAndCacheServerSsids(prefs, token, appUrl);
      }
      if (serverSsids.isEmpty) {
        // Keep polling and report disconnected instead of exiting silently.
        // This avoids appearing "stuck" when router SSID API is temporarily unavailable.
        log('[WifiAttendance] server SSID list empty, continuing with disconnected fallback');
      }

      final connectivityResults = await Connectivity().checkConnectivity();
      final hasWifi = connectivityResults.contains(ConnectivityResult.wifi);

      String currentBssid = '';
      String currentSsid = '';
      if (hasWifi) {
        try {
          currentBssid =
              _normalizeWifiValue(await NetworkInfo().getWifiBSSID());
          currentSsid = _normalizeWifiValue(await NetworkInfo().getWifiName());
        } catch (e) {
          log('[WifiAttendance] wifi info read error: $e');
        }
      }

      final fallbackBssid = _normalizeWifiValue(
        prefs.getString(Preferences.WIFI_LAST_MATCHED_BSSID) ??
            prefs.getString(Preferences.WIFI_OFFICE_BSSID),
      );

      bool onOfficeWifi = hasWifi &&
          serverSsids.isNotEmpty &&
          _matchesOfficeWifi(
            serverSsids,
            currentBssid: currentBssid,
            currentSsid: currentSsid,
          );

      // In background, Android may return placeholder BSSID/SSID even when still on WiFi.
      // Fall back to last matched office BSSID to avoid false "disconnected" polls.
      if (!onOfficeWifi &&
          hasWifi &&
          serverSsids.isNotEmpty &&
          _isPlaceholderBssid(currentBssid) &&
          _isUnknownSsid(currentSsid) &&
          fallbackBssid.isNotEmpty &&
          _matchesOfficeWifi(
            serverSsids,
            currentBssid: fallbackBssid,
            currentSsid: '',
          )) {
        onOfficeWifi = true;
        currentBssid = fallbackBssid;
        log('[WifiAttendance] using fallback office BSSID in background: $fallbackBssid');
      }

      if (onOfficeWifi && currentBssid.isNotEmpty) {
        await prefs.setString(
            Preferences.WIFI_LAST_MATCHED_BSSID, currentBssid);
        await prefs.setString(Preferences.WIFI_OFFICE_BSSID, currentBssid);
      }

      final effectiveCurrentBssid =
          _isPlaceholderBssid(currentBssid) ? '' : currentBssid;
      final bssidForApi = onOfficeWifi
          ? (effectiveCurrentBssid.isNotEmpty
              ? effectiveCurrentBssid
              : fallbackBssid)
          : (fallbackBssid.isNotEmpty ? fallbackBssid : effectiveCurrentBssid);

      final status = onOfficeWifi ? 'connected' : 'disconnected';

      // Sync current attendance session from server and drive auto check-in/out by polling.
      log('[WifiAttendance] ⏳ Fetching attendance status (onOfficeWifi=$onOfficeWifi, status=$status)...');
      final attendanceStatus = await _fetchAttendanceStatus(
        prefs,
        token: token,
        appUrl: appUrl,
      );
      log('[WifiAttendance] 📊 Attendance status: $attendanceStatus');

      if (onOfficeWifi) {
        lastDisconnectedAt = null;
        if (_shouldAttemptAutoCheckIn(attendanceStatus)) {
          final canRetryNow = lastAutoCheckInAttemptAt == null ||
              DateTime.now().difference(lastAutoCheckInAttemptAt!) >=
                  const Duration(seconds: 8);
          if (canRetryNow) {
            lastAutoCheckInAttemptAt = DateTime.now();
            log('[WifiAttendance] ✅ On office WiFi + status=$attendanceStatus → triggering auto check-in');
            final didCheckIn =
                await _autoCheckIn(prefs, token: token, appUrl: appUrl);
            if (didCheckIn) {
              await _fetchAttendanceStatus(
                prefs,
                token: token,
                appUrl: appUrl,
              );
            }
          } else {
            log('[WifiAttendance] ⏳ Skipping auto check-in retry: waiting for short retry window');
          }
        } else {
          log('[WifiAttendance] ℹ️ On office WiFi but status=$attendanceStatus (not checking in)');
        }
      } else {
        lastAutoCheckInAttemptAt = null;
        if (attendanceStatus == 'checked_in') {
          lastDisconnectedAt ??= DateTime.now();
          final disconnectedFor =
              DateTime.now().difference(lastDisconnectedAt!);
          log('[WifiAttendance] 📍 Off WiFi + checked_in: disconnected for ${disconnectedFor.inMinutes}min (threshold: 15min)');
          if (disconnectedFor >= const Duration(minutes: 15)) {
            log('[WifiAttendance] ⏱️ 15-minute threshold reached → triggering auto check-out');
            await _autoCheckOut(prefs, token: token, appUrl: appUrl);
          }
        } else {
          log('[WifiAttendance] ℹ️ Off WiFi but status=$attendanceStatus (not checking out)');
          lastDisconnectedAt = null;
        }
      }

      // KEY POINT: ALWAYS call _postWifiStatus every 30 seconds, regardless of change.
      // The backend API handles duplicates correctly and just updates reconnected_at.
      final backendNotification = await _postWifiStatus(
        token: token,
        appUrl: appUrl,
        status: status,
        routerBssid: bssidForApi,
        currentSsid: currentSsid,
      );

      await prefs.setString(Preferences.WIFI_LAST_POLLED_STATUS, status);

      log('[WifiAttendance] 📤 Poll cycle complete: ✅ APIs called, status=$status, onOffice=$onOfficeWifi, bssid=$bssidForApi');

      service.invoke('statusUpdate', {
        'status': status,
        'onOfficeWifi': onOfficeWifi,
        'routerBssid': bssidForApi,
      });

      if (service is AndroidServiceInstance) {
        final nextNotificationTitle = (backendNotification['title'] ?? '').trim();
        final nextNotificationContent =
            (backendNotification['content'] ?? '').trim();

        // Backend-driven notifications only. If backend sends nothing, do not update.
        if (nextNotificationContent.isNotEmpty &&
            (nextNotificationTitle != lastForegroundNotificationTitle ||
                nextNotificationContent != lastForegroundNotificationContent)) {
          service.setForegroundNotificationInfo(
            title: nextNotificationTitle,
            content: nextNotificationContent,
          );
          lastForegroundNotificationTitle = nextNotificationTitle;
          lastForegroundNotificationContent = nextNotificationContent;
        }
      }
    } catch (e) {
      log('[WifiAttendance] checkAndSyncWifiStatus error: $e');
    } finally {
      isChecking = false;
    }
  }

  periodicTimer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => checkAndSyncWifiStatus(),
  );

  Connectivity().onConnectivityChanged.listen((_) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(seconds: 3), checkAndSyncWifiStatus);
  });

  await checkAndSyncWifiStatus();

  service.on('forceCheck').listen((_) {
    checkAndSyncWifiStatus();
  });

  service.on('stopService').listen((_) {
    debounceTimer?.cancel();
    periodicTimer?.cancel();
    service.stopSelf();
  });
}

class WifiAttendanceService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static final List<void Function()> _statusListeners = [];

  static void addStatusListener(void Function() listener) {
    _statusListeners.add(listener);
  }

  static void removeStatusListener(void Function() listener) {
    _statusListeners.remove(listener);
  }

  static void _notifyStatusListeners() {
    for (final listener in _statusListeners) {
      listener();
    }
  }

  static Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: wifiAttendanceServiceMain,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _kWifiAttendanceChannelId,
        initialNotificationTitle: '',
        initialNotificationContent: '',
        foregroundServiceNotificationId: _kForegroundNotifId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: wifiAttendanceServiceMain,
        onBackground: _onIosBackground,
      ),
    );

    await _ensureNotificationChannel();

    _service.on('statusUpdate').listen((_) {
      _notifyStatusListeners();
    });

    await startService();
  }

  static Future<void> startService() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
      log('[WifiAttendance] service started');
    }
  }

  static Future<void> stopService() async {
    _service.invoke('stopService');
    log('[WifiAttendance] service stopped');
  }

  static Future<void> reconfigure({required bool enabled}) async {
    if (enabled) {
      await startService();
    } else {
      await stopService();
    }
  }

  static void forceCheck() {
    _service.invoke('forceCheck');
  }

  static Future<List<dynamic>> fetchAndCacheServerSsids() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('user_token') ?? '';
      final appUrl = prefs.getString('app_url')?.isNotEmpty == true
          ? prefs.getString('app_url')!
          : Constant.appUrl;
      if (token.isEmpty) return [];
      return _fetchAndCacheServerSsids(prefs, token, appUrl);
    } catch (e) {
      log('[WifiAttendance] fetchAndCacheServerSsids error: $e');
      return [];
    }
  }

  static Future<void> _ensureNotificationChannel() async {
    if (!Platform.isAndroid) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await FlutterLocalNotificationsPlugin().initialize(
      const InitializationSettings(android: androidInit),
    );
    final plugin = FlutterLocalNotificationsPlugin();
    final androidPlugin = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kWifiAttendanceChannelId,
        _kWifiAttendanceChannelName,
        description: 'Notifications for automatic WiFi attendance sync',
        importance: Importance.low,
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}
