import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Simplified background service for WiFi polling - only sends BSSID to backend.
/// Backend handles all verification logic including check-in/check-out marking.
class WifiBackgroundService {
  static const String _channelId = 'wifi_attendance_channel';
  static const String _authTokenKey = 'user_token';
  static const String _baseUrlKey = 'app_url';
  static final WifiBackgroundService _instance = WifiBackgroundService._internal();
  factory WifiBackgroundService() => _instance;
  WifiBackgroundService._internal();

  bool _isInitialized = false;

  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) return;

    final service = FlutterBackgroundService();

    // Configure Android service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'WiFi Attendance',
        initialNotificationContent: 'Service is ready',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _isInitialized = true;
    log('[WifiBackgroundService] Service initialized');
  }

  /// Start the background service
  Future<void> start() async {
    if (!_isInitialized) {
      await initialize();
    }

    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      log('[WifiBackgroundService] Service already running');
      return;
    }

    await service.startService();
    log('[WifiBackgroundService] Service started');
  }

  /// Stop the background service
  Future<void> stop() async {
    final service = FlutterBackgroundService();

    service.invoke('stop');
    log('[WifiBackgroundService] Service stop requested');
  }

  /// Check if service is running
  Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// Service start handler - runs in background isolate
  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Setup notification for Android
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // Handle stop command
    service.on('stop').listen((event) {
      service.stopSelf();
    });

    // Reactive connectivity monitoring - listen for network changes
    final connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;
        final token = prefs.getString(_authTokenKey);
        final baseUrl = prefs.getString(_baseUrlKey);

        if (!enabled || token == null || baseUrl == null) {
          log('[WifiBackgroundService] Service disabled or not authenticated, skipping reactive check');
          return;
        }

        // Perform immediate check on connectivity change
        await _performWifiCheck(prefs, baseUrl, token);

        // Update notification
        if (service is AndroidServiceInstance) {
          await service.setForegroundNotificationInfo(
            title: 'WiFi Attendance Active',
            content: results.contains(ConnectivityResult.wifi) ? 'WiFi Connected' : 'WiFi Disconnected',
          );
        }
      } catch (e) {
        log('[WifiBackgroundService] Error in reactive connectivity monitoring: $e');
      }
    });

    // Main polling loop (fallback for missed connectivity events)
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        // Check if service should be running
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;

        final token = prefs.getString(_authTokenKey);
        final baseUrl = prefs.getString(_baseUrlKey);

        if (!enabled || token == null || baseUrl == null) {
          log('[WifiBackgroundService] Service disabled or not authenticated, stopping');
          connectivitySubscription.cancel();
          timer.cancel();
          service.stopSelf();
          return;
        }

        // Perform WiFi check
        await _performWifiCheck(prefs, baseUrl, token);

        // Update notification
        if (service is AndroidServiceInstance) {
          await service.setForegroundNotificationInfo(
            title: 'WiFi Attendance Active',
            content: 'Checking WiFi status...',
          );
        }
      } catch (e) {
        log('[WifiBackgroundService] Error in polling loop: $e');
      }
    });

    log('[WifiBackgroundService] Background service started successfully');
  }

  /// Perform WiFi status check - only sends BSSID to backend
  static Future<void> _performWifiCheck(
    SharedPreferences prefs,
    String baseUrl,
    String token,
  ) async {
    print('[WifiBackgroundService] ===== _performWifiCheck called =====');
    try {
      String currentBssid = '';
      try {
        currentBssid = _normalize(await NetworkInfo().getWifiBSSID());
        print('[WifiBackgroundService] Current BSSID: $currentBssid');
      } catch (e) {
        print('[WifiBackgroundService] WiFi info read error: $e');
      }

      // Send BSSID to backend - backend handles verification and check-in/check-out
      print('[WifiBackgroundService] Calling _postBssidToBackend');
      await _postBssidToBackend(prefs, baseUrl, token, currentBssid);
    } catch (e) {
      print('[WifiBackgroundService] Error performing WiFi check: $e');
    }
  }

  static String _normalize(String? v) => (v ?? '').trim().replaceAll('"', '').toLowerCase();

  /// Send BSSID to backend for verification
  static Future<void> _postBssidToBackend(
    SharedPreferences prefs,
    String baseUrl,
    String token,
    String bssid,
  ) async {
    try {
      print('[WifiBackgroundService] ===== _postBssidToBackend called =====');
      print('[WifiBackgroundService] BSSID: $bssid');
      print('[WifiBackgroundService] Base URL: $baseUrl');
      print('[WifiBackgroundService] Token: ${token.isNotEmpty ? "present" : "missing"}');

      final uri = Uri.parse('$baseUrl/api/thirdparty/employees/wifi-statusss');
      // Backend expects a simple body with only the BSSID
      final payload = {
        'bssid': bssid,
      };

      print('[WifiBackgroundService] Request URL: $uri');
      print('[WifiBackgroundService] Request payload: ${jsonEncode(payload)}');

      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json; charset=UTF-8',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      print('[WifiBackgroundService] Response status: ${response.statusCode}');
      print('[WifiBackgroundService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('[WifiBackgroundService] BSSID sent to backend successfully: $bssid');
      } else {
        print('[WifiBackgroundService] BSSID post failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[WifiBackgroundService] _postBssidToBackend error: $e');
    }
  }
}
