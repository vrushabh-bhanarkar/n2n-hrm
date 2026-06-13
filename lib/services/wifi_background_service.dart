import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Background service for WiFi polling that runs even when app is terminated
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
  static void onStart(ServiceInstance service) async {
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

    // Main polling loop
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        // Check if service should be running
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;

        final token = prefs.getString(_authTokenKey);
        final baseUrl = prefs.getString(_baseUrlKey);

        if (!enabled || token == null || baseUrl == null) {
          log('[WifiBackgroundService] Service disabled or not authenticated, stopping');
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

  /// Perform WiFi status check
  static Future<void> _performWifiCheck(
    SharedPreferences prefs,
    String baseUrl,
    String token,
  ) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasWifi = connectivityResult.contains(ConnectivityResult.wifi);

      String currentBssid = '';
      String currentSsid = '';
      if (hasWifi) {
        try {
          currentBssid = _normalize(await NetworkInfo().getWifiBSSID());
          currentSsid = _normalize(await NetworkInfo().getWifiName());
        } catch (e) {
          log('[WifiBackgroundService] WiFi info read error: $e');
        }
      }

      final isOffice = await _isConnectedToOfficeWifi(prefs, currentBssid, currentSsid);

      if (isOffice) {
        await _postWifiStatus(prefs, baseUrl, token, status: 'connected', bssid: currentBssid, ssid: currentSsid);
      } else {
        final lastStatus = prefs.getString(Preferences.WIFI_LAST_POLLED_STATUS) ?? 'unknown';
        if (lastStatus == 'connected') {
          await _postWifiStatus(prefs, baseUrl, token, status: 'disconnected', bssid: '', ssid: currentSsid);
        }
      }
    } catch (e) {
      log('[WifiBackgroundService] Error performing WiFi check: $e');
    }
  }

  static String _normalize(String? v) => (v ?? '').trim().replaceAll('"', '').toLowerCase();

  static bool _isMac(String v) => RegExp(r'^[0-9a-f]{2}(:[0-9a-f]{2}){5}').hasMatch(v);

  static List<dynamic> _routerCandidates(Map item) => [
        item['bssid'],
        item['router_bssid'],
        item['router_mac'],
        item['mac'],
        item['ssid'],
        item['name']
      ];

  static Future<bool> _isConnectedToOfficeWifi(
    SharedPreferences prefs,
    String bssid,
    String ssid,
  ) async {
    try {
      final cached = prefs.getString(Preferences.WIFI_SERVER_SSIDS) ?? '';
      List<dynamic> serverSsids = [];
      if (cached.isNotEmpty) {
        try {
          serverSsids = jsonDecode(cached) as List<dynamic>;
        } catch (_) {
          serverSsids = [];
        }
      }

      if (serverSsids.isEmpty) {
        serverSsids = await _fetchServerSsids(prefs, '', '');
      }
      if (serverSsids.isEmpty) return false;

      for (final item in serverSsids) {
        if (item is Map) {
          final candidates = _routerCandidates(item);
          for (final candidate in candidates) {
            final value = _normalize(candidate?.toString());
            if (value.isEmpty) continue;
            if (bssid.isNotEmpty && value == bssid) return true;
            if (!_isMac(value) && ssid.isNotEmpty && value == ssid) return true;
          }
        } else {
          final value = _normalize(item.toString());
          if (value.isEmpty) continue;
          if (bssid.isNotEmpty && value == bssid) return true;
          if (!_isMac(value) && ssid.isNotEmpty && value == ssid) return true;
        }
      }
      return false;
    } catch (e) {
      log('[WifiBackgroundService] _isConnectedToOfficeWifi error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> _fetchServerSsids(
    SharedPreferences prefs,
    String baseUrl,
    String token,
  ) async {
    try {
      // Get fresh baseUrl and token from prefs

      final freshBaseUrl = prefs.getString(_baseUrlKey);
      final freshToken = prefs.getString(_authTokenKey);
      
      if (freshBaseUrl == null || freshToken == null) {
        return [];
      }

      final uri = Uri.parse('$freshBaseUrl${Constant.ROUTER_SSID_URL}');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $freshToken',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];
      final payload = jsonDecode(response.body);
      List<dynamic> filtered = [];
      if (payload is Map && payload['data'] is List) {
        filtered = (payload['data'] as List).where((s) => s is Map).toList();
      } else if (payload is List) {
        filtered = payload.where((s) => s is Map).toList();
      }
      await prefs.setString(Preferences.WIFI_SERVER_SSIDS, jsonEncode(filtered));
      return filtered;
    } catch (e) {
      log('[WifiBackgroundService] _fetchServerSsids error: $e');
      return [];
    }
  }

  static Future<void> _postWifiStatus(
    SharedPreferences prefs,
    String baseUrl,
    String token, {
    required String status,
    required String? bssid,
    required String? ssid,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl${Constant.WIFI_STATUS_URL}');
      final payload = {
        'status': status,
        'router_bssid': bssid ?? '',
        'ssid': ssid ?? '',
        'is_auto': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json; charset=UTF-8',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await prefs.setString(Preferences.WIFI_LAST_POLLED_STATUS, status);
        log('[WifiBackgroundService] heartbeat $status posted');
      } else {
        log('[WifiBackgroundService] heartbeat post failed: ${response.statusCode}');
      }
    } catch (e) {
      log('[WifiBackgroundService] _postWifiStatus error: $e');
    }
  }
}
