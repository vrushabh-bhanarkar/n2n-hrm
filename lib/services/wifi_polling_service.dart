import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Clean, single implementation for heartbeat-only WiFi polling service.
class WifiPollingService {
  static const Duration _pollingInterval = Duration(seconds: 15);
  static const int _maxDisconnectRetries = 2;

  final SharedPreferences preferences;
  final String baseUrl;
  final String token;
  final void Function()? onStatusUpdate;

  Timer? _pollingTimer;
  int _disconnectCounter = 0;
  String _lastReportedStatus = 'unknown';

  WifiPollingService({
    required this.preferences,
    required this.baseUrl,
    required this.token,
    this.onStatusUpdate,
  }) {
    _lastReportedStatus = preferences.getString(Preferences.WIFI_LAST_POLLED_STATUS) ?? 'unknown';
  }

  void startPolling() {
    if (_pollingTimer != null) return;
    _pollingTimer = Timer.periodic(_pollingInterval, (_) => _checkAndSync());
    _checkAndSync();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  String _normalize(String? v) => (v ?? '').trim().replaceAll('"', '').toLowerCase();

  bool _isMac(String v) => RegExp(r'^[0-9a-f]{2}(:[0-9a-f]{2}){5}').hasMatch(v);

  List<dynamic> _routerCandidates(Map item) => [item['bssid'], item['router_bssid'], item['router_mac'], item['mac'], item['ssid'], item['name']];

  Future<List<dynamic>> _fetchServerSsids() async {
    try {
      final uri = Uri.parse('$baseUrl${Constant.ROUTER_SSID_URL}');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];
      final payload = jsonDecode(response.body);
      List<dynamic> filtered = [];
      if (payload is Map && payload['data'] is List) {
        filtered = (payload['data'] as List).where((s) => s is Map).toList();
      } else if (payload is List) {
        filtered = payload.where((s) => s is Map).toList();
      }
      await preferences.setString(Preferences.WIFI_SERVER_SSIDS, jsonEncode(filtered));
      return filtered;
    } catch (e) {
      log('[WifiPolling] _fetchServerSsids error: $e');
      return [];
    }
  }

  Future<bool> _isConnectedToOfficeWifi(String bssid, String ssid) async {
    try {
      final cached = preferences.getString(Preferences.WIFI_SERVER_SSIDS) ?? '';
      List<dynamic> serverSsids = [];
      if (cached.isNotEmpty) {
        try {
          serverSsids = jsonDecode(cached) as List<dynamic>;
        } catch (_) {
          serverSsids = [];
        }
      }

      if (serverSsids.isEmpty) {
        serverSsids = await _fetchServerSsids();
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
      log('[WifiPolling] _isConnectedToOfficeWifi error: $e');
      return false;
    }
  }

  Future<void> _checkAndSync() async {
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
          log('[WifiPolling] WiFi info read error: $e');
        }
      }

      final isOffice = await _isConnectedToOfficeWifi(currentBssid, currentSsid);

      if (isOffice) {
        _disconnectCounter = 0;
        await _postWifiStatus(status: 'connected', bssid: currentBssid, ssid: currentSsid);
        _lastReportedStatus = 'connected';
      } else {
        if (_lastReportedStatus == 'connected') {
          _disconnectCounter++;
          log('[WifiPolling] debounce missing count=$_disconnectCounter');
          if (_disconnectCounter >= _maxDisconnectRetries) {
            await _postWifiStatus(status: 'disconnected', bssid: '', ssid: currentSsid);
            _lastReportedStatus = 'disconnected';
            _disconnectCounter = 0;
          }
        }
      }

      try {
        onStatusUpdate?.call();
      } catch (e) {
        log('[WifiPolling] onStatusUpdate error: $e');
      }
    } catch (e) {
      log('[WifiPolling] _checkAndSync error: $e');
    }
  }

  Future<void> _postWifiStatus({required String status, required String? bssid, required String? ssid}) async {
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
        await preferences.setString(Preferences.WIFI_LAST_POLLED_STATUS, status);
        log('[WifiPolling] heartbeat $status posted');
      } else {
        log('[WifiPolling] heartbeat post failed: ${response.statusCode}');
      }
    } catch (e) {
      log('[WifiPolling] _postWifiStatus error: $e');
    }
  }
}