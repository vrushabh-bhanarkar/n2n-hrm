import 'dart:developer';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Requests WiFi/background permissions once during setup — avoids repeated system popups.
class WifiPermissionsHelper {
  static const String _setupAskedKey = 'wifi_setup_permissions_asked';

  /// Call after login when starting WiFi auto-attendance (not on every cold start).
  static Future<void> requestForWifiAttendanceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_setupAskedKey) == true) {
      return;
    }

    try {
      if (Platform.isAndroid) {
        await _requestAndroidPermissions();
      } else if (Platform.isIOS) {
        await _requestIosPermissions();
      }

      await prefs.setBool(_setupAskedKey, true);
      log('[WifiPermissions] Setup permissions flow completed');
    } catch (e) {
      log('[WifiPermissions] Setup permissions error: $e');
    }
  }

  static Future<void> _requestAndroidPermissions() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }
    }

    var whenInUse = await Permission.locationWhenInUse.status;
    if (!whenInUse.isGranted) {
      whenInUse = await Permission.locationWhenInUse.request();
    }

    if (whenInUse.isGranted) {
      final alwaysStatus = await Permission.locationAlways.status;
      if (!alwaysStatus.isGranted && !alwaysStatus.isPermanentlyDenied) {
        await Permission.locationAlways.request();
      }
    }

    if (androidInfo.version.sdkInt >= 33) {
      final nearbyWifi = await Permission.nearbyWifiDevices.status;
      if (!nearbyWifi.isGranted && !nearbyWifi.isPermanentlyDenied) {
        await Permission.nearbyWifiDevices.request();
      }
    }

    // Battery optimization — ask once here (not on every app launch).
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted && !batteryStatus.isPermanentlyDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  static Future<void> _requestIosPermissions() async {
    var whenInUse = await Permission.locationWhenInUse.status;
    if (!whenInUse.isGranted) {
      whenInUse = await Permission.locationWhenInUse.request();
    }

    if (whenInUse.isGranted) {
      final alwaysStatus = await Permission.locationAlways.status;
      if (!alwaysStatus.isGranted && !alwaysStatus.isPermanentlyDenied) {
        await Permission.locationAlways.request();
      }
    }
  }
}
