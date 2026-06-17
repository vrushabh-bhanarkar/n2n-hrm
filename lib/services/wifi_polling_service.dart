import 'dart:async';
import 'dart:developer';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/wifi_bssid_sync.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foreground WiFi polling while the app is open — pauses when app is backgrounded
/// (Android background service handles polling then).
class WifiPollingService {
  static const Duration wifiConnectedInterval = Duration(seconds: 15);
  static const Duration disconnectedInterval = Duration(seconds: 60);

  final SharedPreferences preferences;
  final String baseUrl;
  final String token;
  final void Function()? onStatusUpdate;

  Timer? _pollingTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _onWifi = false;

  WifiPollingService({
    required this.preferences,
    required this.baseUrl,
    required this.token,
    this.onStatusUpdate,
  });

  void startPolling() {
    if (_pollingTimer != null) {
      return;
    }

    _connectivitySubscription ??=
        Connectivity().onConnectivityChanged.listen((results) {
      final wifiConnected = results.contains(ConnectivityResult.wifi);
      if (wifiConnected != _onWifi) {
        _onWifi = wifiConnected;
        _restartTimer();
      }
      _checkAndSync();
    });

    Connectivity().checkConnectivity().then((results) {
      _onWifi = results.contains(ConnectivityResult.wifi);
      _restartTimer();
    });

    _checkAndSync();
  }

  void _restartTimer() {
    _pollingTimer?.cancel();
    final interval =
        _onWifi ? wifiConnectedInterval : disconnectedInterval;
    _pollingTimer = Timer.periodic(interval, (_) => _checkAndSync());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<void> forceCheck() => _checkAndSync();

  Future<void> _checkAndSync() async {
    try {
      final enabled =
          preferences.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;
      if (!enabled) {
        return;
      }

      await WifiBssidSync.postBssidToBackend(baseUrl: baseUrl, token: token);

      try {
        onStatusUpdate?.call();
      } catch (e) {
        log('[WifiPolling] onStatusUpdate error: $e');
      }
    } catch (e) {
      log('[WifiPolling] _checkAndSync error: $e');
    }
  }
}
