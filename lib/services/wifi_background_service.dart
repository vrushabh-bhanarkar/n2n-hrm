import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/wifi_bssid_sync.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background WiFi polling — keeps sending BSSID to backend when app is closed/swiped away.
/// Backend handles check-in/check-out based on the response.
@pragma('vm:entry-point')
class WifiBackgroundService {
  static const String channelId = 'wifi_attendance_channel';
  static const String authTokenKey = 'user_token';
  static const String baseUrlKey = 'app_url';

  static const Duration wifiConnectedInterval = Duration(seconds: 15);
  static const Duration disconnectedInterval = Duration(seconds: 60);

  static final WifiBackgroundService _instance = WifiBackgroundService._internal();
  factory WifiBackgroundService() => _instance;
  WifiBackgroundService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: channelId,
        initialNotificationTitle: 'WiFi Attendance',
        initialNotificationContent: 'Monitoring WiFi status',
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

  Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
    log('[WifiBackgroundService] Service stop requested');
  }

  Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return service.isRunning();
  }

  static bool _isWifiConnected(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.wifi);
  }

  static Future<({bool enabled, String? token, String? baseUrl})> _readAuthState(
    SharedPreferences prefs,
  ) async {
    final enabled = prefs.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;
    final token = prefs.getString(authTokenKey);
    final baseUrl = prefs.getString(baseUrlKey);
    return (enabled: enabled, token: token, baseUrl: baseUrl);
  }

  static Future<bool> _shouldKeepRunning(SharedPreferences prefs) async {
    final state = await _readAuthState(prefs);
    return state.enabled &&
        state.token != null &&
        state.token!.isNotEmpty &&
        state.baseUrl != null &&
        state.baseUrl!.isNotEmpty;
  }

  static Future<void> _performWifiCheck(
    SharedPreferences prefs,
    String baseUrl,
    String token,
  ) async {
    log('[WifiBackgroundService] Performing WiFi check to $baseUrl');
    final success = await WifiBssidSync.postBssidToBackend(baseUrl: baseUrl, token: token);
    log('[WifiBackgroundService] WiFi check result: $success');
  }

  /// iOS background entry — run one sync when iOS grants background time.
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await _shouldKeepRunning(prefs)) {
        return true;
      }

      final state = await _readAuthState(prefs);
      await _performWifiCheck(prefs, state.baseUrl!, state.token!);
    } catch (e) {
      log('[WifiBackgroundService] iOS background sync error: $e');
    }

    return true;
  }

  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((_) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((_) {
        service.setAsBackgroundService();
      });

      await service.setForegroundNotificationInfo(
        title: 'WiFi Attendance Active',
        content: 'Monitoring WiFi status',
      );
    }

    StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
    Timer? pollingTimer;
    var onWifi = false;

    Future<void> stopService() async {
      try {
        await connectivitySubscription?.cancel();
      } catch (_) {}
      try {
        pollingTimer?.cancel();
      } catch (_) {}
      service.stopSelf();
    }

    Future<void> runCheck() async {
      log('[WifiBackgroundService] Running WiFi check...');
      final prefs = await SharedPreferences.getInstance();
      if (!await _shouldKeepRunning(prefs)) {
        log('[WifiBackgroundService] Not authenticated or disabled, stopping');
        await stopService();
        return;
      }

      final state = await _readAuthState(prefs);
      log('[WifiBackgroundService] Auth state - enabled: ${state.enabled}, hasToken: ${state.token != null}, hasBaseUrl: ${state.baseUrl != null}');
      await _performWifiCheck(prefs, state.baseUrl!, state.token!);
    }

    void schedulePolling(bool wifiConnected) {
      pollingTimer?.cancel();
      onWifi = wifiConnected;
      final interval = wifiConnected ? wifiConnectedInterval : disconnectedInterval;
      log('[WifiBackgroundService] Scheduling polling every ${interval.inSeconds}s (WiFi connected: $wifiConnected)');

      pollingTimer = Timer.periodic(interval, (_) async {
        log('[WifiBackgroundService] Polling timer triggered');
        await runCheck();
      });
    }

    // Immediate check when service starts (e.g. after login or app removed from recents).
    try {
      final initialConnectivity = await Connectivity().checkConnectivity();
      onWifi = _isWifiConnected(initialConnectivity);
      schedulePolling(onWifi);
      await runCheck();
    } catch (e) {
      log('[WifiBackgroundService] Initial check error: $e');
      schedulePolling(false);
    }

    connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      try {
        final wifiConnected = _isWifiConnected(results);
        log('[WifiBackgroundService] Connectivity changed: $results, WiFi connected: $wifiConnected, was $onWifi');
        if (wifiConnected != onWifi) {
          schedulePolling(wifiConnected);
          
          // Only clear cached BSSID when WiFi disconnects, not when it reconnects
          if (!wifiConnected) {
            await WifiBssidSync.clearCachedBssid();
            log('[WifiBackgroundService] WiFi disconnected, cleared cached BSSID');
          } else {
            log('[WifiBackgroundService] WiFi reconnected, keeping cached BSSID as fallback');
          }
        }

        await runCheck();

        if (service is AndroidServiceInstance) {
          await service.setForegroundNotificationInfo(
            title: 'WiFi Attendance Active',
            content: wifiConnected ? 'WiFi connected' : 'Waiting for WiFi',
          );
        }
      } catch (e) {
        log('[WifiBackgroundService] Connectivity handler error: $e');
      }
    });

    service.on('stop').listen((_) async {
      await stopService();
    });

    log('[WifiBackgroundService] Background service started (${Platform.operatingSystem})');
  }
}
