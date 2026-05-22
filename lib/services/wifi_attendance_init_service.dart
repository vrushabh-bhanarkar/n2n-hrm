import 'dart:developer';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/wifi_polling_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WiFi Attendance Initialization Service
/// 
/// Handles WiFi polling lifecycle management:
/// - Initializes WiFi polling after successful login
/// - Cleans up WiFi polling on logout
/// - Provides WiFi status and control methods

class WifiAttendanceInitService {
  static final WifiAttendanceInitService _instance =
      WifiAttendanceInitService._internal();

  factory WifiAttendanceInitService() {
    return _instance;
  }

  WifiAttendanceInitService._internal();

  bool _initialized = false;

  bool get initialized => _initialized;

  /// Initialize WiFi polling after user login
  /// Call this from the login screen or dashboard after successful authentication
  Future<bool> initializeForUser({
    required String baseUrl,
    required String token,
  }) async {
    try {
      if (_initialized) {
        log('[WiFiInit] Already initialized, skipping');
        return true;
      }

      // Check if WiFi auto-attendance is enabled
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;

      if (!enabled) {
        log('[WiFiInit] WiFi auto-attendance is disabled');
        return false;
      }

      // Start WiFi polling
      await WifiPollingManager().startPolling(
        baseUrl: baseUrl,
        token: token,
      );

      _initialized = true;
      log('[WiFiInit] WiFi polling initialized successfully');
      return true;
    } catch (e) {
      log('[WiFiInit] Error initializing WiFi polling: $e');
      return false;
    }
  }

  /// Clean up WiFi polling on logout
  /// Call this when user logs out or app is terminated
  Future<void> cleanupOnLogout() async {
    try {
      await WifiPollingManager().stopPolling();
      _initialized = false;
      log('[WiFiInit] WiFi polling cleaned up on logout');
    } catch (e) {
      log('[WiFiInit] Error cleaning up WiFi polling: $e');
    }
  }

  /// Toggle WiFi auto-attendance on/off
  Future<void> toggleWifiAttendance({required bool enabled}) async {
    try {
      await WifiPollingManager().setWifiAttendanceEnabled(enabled);
      log('[WiFiInit] WiFi auto-attendance ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      log('[WiFiInit] Error toggling WiFi attendance: $e');
    }
  }

  /// Get WiFi polling status
  Map<String, dynamic> getStatus() {
    return WifiPollingManager().getStatus();
  }

  /// Force immediate WiFi check
  Future<void> forceWifiCheck() async {
    try {
      await WifiPollingManager().forceCheck();
      log('[WiFiInit] Forced WiFi status check');
    } catch (e) {
      log('[WiFiInit] Error forcing WiFi check: $e');
    }
  }

  /// Reset initialization state (for testing or cleanup)
  void reset() {
    _initialized = false;
    log('[WiFiInit] Initialization state reset');
  }
}
