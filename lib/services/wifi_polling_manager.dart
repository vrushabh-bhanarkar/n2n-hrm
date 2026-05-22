import 'dart:developer';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/wifi_polling_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WiFi Polling Integration Manager
/// 
/// Manages WiFi polling service lifecycle and coordinates with app state
/// - Starts polling after user login
/// - Stops polling on logout
/// - Pauses polling when app goes to background
/// - Resumes polling when app comes to foreground

class WifiPollingManager {
  static final WifiPollingManager _instance = WifiPollingManager._internal();
  
  factory WifiPollingManager() {
    return _instance;
  }
  
  WifiPollingManager._internal();

  WifiPollingService? _pollingService;
  bool _isRunning = false;
  bool _isPaused = false;

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;

  /// Initialize WiFi polling service
  /// Call this after successful user login
  Future<void> startPolling({
    required String baseUrl,
    required String token,
  }) async {
    if (_isRunning) {
      log('[WifiPolling] Service already running, skipping start');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if WiFi auto-attendance is enabled
      final enabled = prefs.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;
      if (!enabled) {
        log('[WifiPolling] WiFi auto-attendance is disabled');
        return;
      }

      _pollingService = WifiPollingService(
        preferences: prefs,
        baseUrl: baseUrl,
        token: token,
      );

      _pollingService!.startPolling();
      _isRunning = true;
      _isPaused = false;

      log('[WifiPolling] Polling service started');
    } catch (e) {
      log('[WifiPolling] Error starting polling service: $e');
    }
  }

  /// Stop WiFi polling service
  /// Call this on logout or app termination
  Future<void> stopPolling() async {
    try {
      _pollingService?.stopPolling();
      _isRunning = false;
      _isPaused = false;
      log('[WifiPolling] Polling service stopped');
    } catch (e) {
      log('[WifiPolling] Error stopping polling service: $e');
    }
  }

  /// Pause WiFi polling (e.g., when app goes to background)
  Future<void> pausePolling() async {
    if (!_isRunning || _isPaused) {
      return;
    }

    try {
      _pollingService?.stopPolling();
      _isPaused = true;
      log('[WifiPolling] Polling service paused');
    } catch (e) {
      log('[WifiPolling] Error pausing polling service: $e');
    }
  }

  /// Resume WiFi polling (e.g., when app comes to foreground)
  Future<void> resumePolling() async {
    if (!_isRunning || !_isPaused) {
      return;
    }

    try {
      _pollingService?.startPolling();
      _isPaused = false;
      log('[WifiPolling] Polling service resumed');
    } catch (e) {
      log('[WifiPolling] Error resuming polling service: $e');
    }
  }

  /// Force immediate WiFi status check
  Future<void> forceCheck() async {
    if (!_isRunning) {
      log('[WifiPolling] Service not running, cannot force check');
      return;
    }

    try {
      // Trigger immediate poll by restarting the service
      _pollingService?.stopPolling();
      await Future.delayed(Duration(milliseconds: 100));
      _pollingService?.startPolling();
      log('[WifiPolling] Forced immediate WiFi status check');
    } catch (e) {
      log('[WifiPolling] Error forcing WiFi check: $e');
    }
  }

  /// Check if WiFi auto-attendance is enabled
  Future<bool> isWifiAttendanceEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;
    } catch (e) {
      log('[WifiPolling] Error checking WiFi auto-attendance status: $e');
      return false;
    }
  }

  /// Enable/disable WiFi auto-attendance
  Future<void> setWifiAttendanceEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(Preferences.WIFI_AUTO_ENABLED, enabled);

      if (enabled && !_isRunning) {
        //Auto-start if not running
        log('[WifiPolling] WiFi auto-attendance enabled, but service not running');
      } else if (!enabled && _isRunning) {
        // Auto-stop if running
        await stopPolling();
      }

      log('[WifiPolling] WiFi auto-attendance ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      log('[WifiPolling] Error setting WiFi auto-attendance: $e');
    }
  }

  /// Get current polling service status
  Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'isPaused': _isPaused,
      'serviceInitialized': _pollingService != null,
    };
  }
}
