import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/wifi_bssid_sync.dart';
import 'package:cnattendance/services/native_wifi_bssid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
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

    // Always force-restart to ensure latest code is running in the background isolate.
    if (await service.isRunning()) {
      log('[WifiBackgroundService] Stopping stale service before restart...');
      service.invoke('stop');
      await Future.delayed(const Duration(seconds: 2));
    }

    // Pre-cache BSSID from foreground so background has a fallback
    try {
      final bssid = WifiBssidSync.normalize(await NativeWifiBssid.getWifiBssid());
      if (WifiBssidSync.isValidBssid(bssid)) {
        await WifiBssidSync.cacheBssid(bssid);
        log('[WifiBackgroundService] Pre-cached BSSID from foreground: $bssid');
      }
    } catch (_) {}

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
    NetworkInfo networkInfo,
  ) async {
    log('[WifiBackgroundService] Performing WiFi check to $baseUrl');

    // Read BSSID directly via network_info_plus (registered in background isolate)
    String? bssid;
    try {
      bssid = await networkInfo.getWifiBSSID();
    } catch (e) {
      log('[WifiBackgroundService] network_info_plus getWifiBSSID error: $e');
    }

    final normalizedBssid = WifiBssidSync.normalize(bssid);

    // If live read fails, try cached BSSID
    String finalBssid = normalizedBssid;
    if (!WifiBssidSync.isValidBssid(finalBssid)) {
      log('[WifiBackgroundService] Live BSSID invalid ($normalizedBssid), trying cache...');
      final cached = await SharedPreferences.getInstance();
      finalBssid = cached.getString('last_valid_bssid') ?? '';
      if (WifiBssidSync.isValidBssid(finalBssid)) {
        log('[WifiBackgroundService] Using cached BSSID: $finalBssid');
      }
    } else {
      // Cache valid live BSSID for future fallback
      await WifiBssidSync.cacheBssid(finalBssid);
    }

    if (!WifiBssidSync.isValidBssid(finalBssid)) {
      log('[WifiBackgroundService] No valid BSSID available, skipping sync');
      return;
    }

    final success = await WifiBssidSync.postBssidToBackend(
      baseUrl: baseUrl,
      token: token,
      bssid: finalBssid,
    );
    log('[WifiBackgroundService] WiFi check result: $success');
  }

  /// Retry BSSID reading after WiFi reconnection
  static Future<void> _retryBssidReadAfterReconnect(
    NetworkInfo networkInfo,
    AndroidServiceInstance service,
  ) async {
    final delays = [
      const Duration(seconds: 2),
      const Duration(seconds: 5),
      const Duration(seconds: 10),
    ];

    for (var i = 0; i < delays.length; i++) {
      if (i > 0) {
        log('[WifiBackgroundService] Retry ${i + 1}/${delays.length}, waiting ${delays[i].inSeconds}s...');
        await Future.delayed(delays[i]);
      }

      String? bssid;
      try {
        bssid = await networkInfo.getWifiBSSID();
      } catch (_) {}

      final normalized = WifiBssidSync.normalize(bssid);
      log('[WifiBackgroundService] Retry ${i + 1}/${delays.length}: BSSID read: "$normalized"');

      if (WifiBssidSync.isValidBssid(normalized)) {
        await WifiBssidSync.cacheBssid(normalized);
        log('[WifiBackgroundService] Valid BSSID obtained after retry: $normalized');
        await service.setForegroundNotificationInfo(
          title: 'WiFi Attendance Active',
          content: 'BSSID: $normalized',
        );
        return;
      }
    }

    log('[WifiBackgroundService] All retries failed, could not obtain valid BSSID');
  }

  /// iOS background entry
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
      final networkInfo = NetworkInfo();
      await _performWifiCheck(prefs, state.baseUrl!, state.token!, networkInfo);
    } catch (e) {
      log('[WifiBackgroundService] iOS background sync error: $e');
    }

    return true;
  }

  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    // FIX 1: Re-initialize native plugin channel bindings in the background isolate.
    // When swiped away, the UI thread dies. This reconnects plugins to platform binaries.
    DartPluginRegistrant.ensureInitialized();

    // FIX 2: Intercept lifecycle shutdown to keep hardware streams alive after swipe.
    // Android tells the app it's terminating on swipe; this blocks that signal.
    SystemChannels.lifecycle.setMessageHandler((msg) async => null);

    final NetworkInfo networkInfo = NetworkInfo();

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
      await _performWifiCheck(prefs, state.baseUrl!, state.token!, networkInfo);

      // Update notification with live BSSID for visual confirmation
      if (service is AndroidServiceInstance) {
        try {
          final bssid = await networkInfo.getWifiBSSID();
          final ssid = await networkInfo.getWifiName();
          await service.setForegroundNotificationInfo(
            title: 'WiFi Attendance Active',
            content: 'BSSID: ${bssid ?? 'N/A'} | SSID: ${ssid ?? 'N/A'}',
          );
        } catch (_) {}
      }
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

    // Immediate check when service starts
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

          if (wifiConnected) {
            log('[WifiBackgroundService] WiFi reconnected, attempting BSSID read with retries...');
            await _retryBssidReadAfterReconnect(networkInfo, service as AndroidServiceInstance);
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
