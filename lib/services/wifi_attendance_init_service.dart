import 'dart:developer';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/wifi_background_service.dart';
import 'package:cnattendance/services/wifi_permissions_helper.dart';
import 'package:cnattendance/services/wifi_polling_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WiFi attendance lifecycle: permissions, foreground polling, and background service.
class WifiAttendanceInitService {
  static final WifiAttendanceInitService _instance =
      WifiAttendanceInitService._internal();

  factory WifiAttendanceInitService() => _instance;

  WifiAttendanceInitService._internal();

  bool _initialized = false;

  bool get initialized => _initialized;

  Future<bool> initializeForUser({
    required String baseUrl,
    required String token,
  }) async {
    try {
      if (token.isEmpty) {
        log('[WiFiInit] Missing auth token, skipping');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();

      // Enable WiFi auto-attendance by default on first dashboard load after login.
      if (!prefs.containsKey(Preferences.WIFI_AUTO_ENABLED)) {
        await prefs.setBool(Preferences.WIFI_AUTO_ENABLED, true);
      }

      final enabled = prefs.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;
      if (!enabled) {
        log('[WiFiInit] WiFi auto-attendance is disabled');
        return false;
      }

      // Ask WiFi/background permissions once (not on every cold start).
      await WifiPermissionsHelper.requestForWifiAttendanceIfNeeded();

      if (!_initialized) {
        await WifiBackgroundService().initialize();
      }

      // Background service keeps polling when app is swiped away (Android + iOS).
      await WifiBackgroundService().start();
      log('[WiFiInit] Background WiFi service started');

      // Foreground polling for UI refresh while app is open.
      await WifiPollingManager().startPolling(
        baseUrl: baseUrl,
        token: token,
      );
      await WifiPollingManager().forceCheck();

      _initialized = true;
      log('[WiFiInit] WiFi attendance initialized');
      return true;
    } catch (e) {
      log('[WiFiInit] Error initializing WiFi attendance: $e');
      return false;
    }
  }

  Future<void> cleanupOnLogout() async {
    try {
      await WifiBackgroundService().stop();
      await WifiPollingManager().stopPolling();
      _initialized = false;
      log('[WiFiInit] WiFi attendance cleaned up on logout');
    } catch (e) {
      log('[WiFiInit] Error cleaning up WiFi attendance: $e');
    }
  }

  Future<void> toggleWifiAttendance({required bool enabled}) async {
    try {
      await WifiPollingManager().setWifiAttendanceEnabled(enabled);

      if (enabled) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('user_token') ?? '';
        final baseUrl = prefs.getString('app_url') ?? '';
        if (token.isNotEmpty && baseUrl.isNotEmpty) {
          await initializeForUser(baseUrl: baseUrl, token: token);
        }
      } else {
        await WifiBackgroundService().stop();
        _initialized = false;
      }

      log('[WiFiInit] WiFi auto-attendance ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      log('[WiFiInit] Error toggling WiFi attendance: $e');
    }
  }

  Map<String, dynamic> getStatus() => WifiPollingManager().getStatus();

  Future<void> forceWifiCheck() async {
    try {
      await WifiPollingManager().forceCheck();
      log('[WiFiInit] Forced WiFi status check');
    } catch (e) {
      log('[WiFiInit] Error forcing WiFi check: $e');
    }
  }

  void reset() {
    _initialized = false;
    log('[WiFiInit] Initialization state reset');
  }
}
