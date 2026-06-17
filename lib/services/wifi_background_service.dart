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
import 'package:geolocator/geolocator.dart';
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
        if (results.contains(ConnectivityResult.wifi)) {
          log('[WifiBackgroundService] WiFi connected - performing immediate check');
          await _performWifiCheck(prefs, baseUrl, token);
        } else {
          log('[WifiBackgroundService] WiFi disconnected - performing immediate check');
          await _performWifiCheck(prefs, baseUrl, token);
        }

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

  /// Perform WiFi status check with location tracking and check-in/check-out logic
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

      // Get current location
      double? latitude;
      double? longitude;
      double? accuracy;
      bool isWithinOfficeGeofence = false;

      try {
        final position = await _getCurrentLocation();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
          accuracy = position.accuracy;

          // Check if within office geofence
          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            Constant.OFFICE_LATITUDE,
            Constant.OFFICE_LONGITUDE,
          );
          isWithinOfficeGeofence = distance <= Constant.OFFICE_GEOFENCE_RADIUS_METERS;

          log('[WifiBackgroundService] Location: $latitude, $longitude, accuracy: ${accuracy}m, distance to office: ${distance}m');
        }
      } catch (e) {
        log('[WifiBackgroundService] Location error: $e');
      }

      if (isOffice && isWithinOfficeGeofence) {
        // Connected to office WiFi and within office geofence - mark check-in
        await _postWifiStatus(prefs, baseUrl, token, status: 'connected', bssid: currentBssid, ssid: currentSsid, latitude: latitude, longitude: longitude, accuracy: accuracy);
        await _performCheckIn(prefs, baseUrl, token, latitude, longitude, accuracy);
      } else if (!isOffice || !isWithinOfficeGeofence) {
        final lastStatus = prefs.getString(Preferences.WIFI_LAST_POLLED_STATUS) ?? 'unknown';
        if (lastStatus == 'connected') {
          // Disconnected from office WiFi or left office geofence - mark check-out
          await _postWifiStatus(prefs, baseUrl, token, status: 'disconnected', bssid: '', ssid: currentSsid, latitude: latitude, longitude: longitude, accuracy: accuracy);
          await _performCheckOut(prefs, baseUrl, token, latitude, longitude, accuracy);
        }
      }
    } catch (e) {
      log('[WifiBackgroundService] Error performing WiFi check: $e');
    }
  }

  /// Get current device location
  static Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        log('[WifiBackgroundService] Location service is disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          log('[WifiBackgroundService] Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        log('[WifiBackgroundService] Location permission denied forever');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      log('[WifiBackgroundService] Error getting location: $e');
      return null;
    }
  }

  /// Perform check-in API call
  static Future<void> _performCheckIn(
    SharedPreferences prefs,
    String baseUrl,
    String token,
    double? latitude,
    double? longitude,
    double? accuracy,
  ) async {
    try {
      final lastCheckInTime = prefs.getInt(Preferences.WIFI_LAST_LOCATION_UPDATE_MS) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Avoid duplicate check-ins within 5 minutes
      if (now - lastCheckInTime < 5 * 60 * 1000) {
        log('[WifiBackgroundService] Check-in already performed recently, skipping');
        return;
      }

      final uri = Uri.parse('$baseUrl${Constant.CHECK_IN_URL}');
      final payload = {
        'latitude': latitude?.toString() ?? '',
        'longitude': longitude?.toString() ?? '',
        'accuracy': accuracy?.toString() ?? '',
        'is_auto': true,
        'timestamp': now,
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setInt(Preferences.WIFI_LAST_LOCATION_UPDATE_MS, now);
        log('[WifiBackgroundService] Auto check-in successful');
      } else {
        // Silent failure logging to avoid system crashes in background execution
        log('[WifiBackgroundService] Auto check-in failed: ${response.statusCode} - logging silently');
      }
    } catch (e) {
      // Silent failure logging to avoid system crashes in background execution
      log('[WifiBackgroundService] Check-in error (silent): ${e.toString()}');
    }
  }

  /// Perform check-out API call
  static Future<void> _performCheckOut(
    SharedPreferences prefs,
    String baseUrl,
    String token,
    double? latitude,
    double? longitude,
    double? accuracy,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl${Constant.CHECK_OUT_URL}');
      final payload = {
        'latitude': latitude?.toString() ?? '',
        'longitude': longitude?.toString() ?? '',
        'accuracy': accuracy?.toString() ?? '',
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        log('[WifiBackgroundService] Auto check-out successful');
      } else {
        // Silent failure logging to avoid system crashes in background execution
        log('[WifiBackgroundService] Auto check-out failed: ${response.statusCode} - logging silently');
      }
    } catch (e) {
      // Silent failure logging to avoid system crashes in background execution
      log('[WifiBackgroundService] Check-out error (silent): ${e.toString()}');
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
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl${Constant.WIFI_STATUS_URL}');
      final payload = {
        'status': status,
        'router_bssid': bssid ?? '',
        'ssid': ssid ?? '',
        'latitude': latitude?.toString() ?? '',
        'longitude': longitude?.toString() ?? '',
        'accuracy': accuracy?.toString() ?? '',
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
        log('[WifiBackgroundService] heartbeat $status posted with location: $latitude, $longitude');
      } else {
        log('[WifiBackgroundService] heartbeat post failed: ${response.statusCode}');
      }
    } catch (e) {
      log('[WifiBackgroundService] _postWifiStatus error: $e');
    }
  }
}
