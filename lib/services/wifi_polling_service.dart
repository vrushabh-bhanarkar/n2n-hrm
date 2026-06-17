import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Simplified WiFi polling service - only sends BSSID to backend for verification.
/// Backend handles all verification logic including check-in/check-out marking.
class WifiPollingService {
  static const Duration _pollingInterval = Duration(seconds: 15);

  final SharedPreferences preferences;
  final String baseUrl;
  final String token;
  final void Function()? onStatusUpdate;

  Timer? _pollingTimer;

  WifiPollingService({
    required this.preferences,
    required this.baseUrl,
    required this.token,
    this.onStatusUpdate,
  });

  void startPolling() {
    print('[WifiPolling] ===== startPolling called =====');
    if (_pollingTimer != null) {
      print('[WifiPolling] Polling timer already exists, skipping');
      return;
    }
    print('[WifiPolling] Starting polling timer with interval: $_pollingInterval');
    _pollingTimer = Timer.periodic(_pollingInterval, (_) => _checkAndSync());
    print('[WifiPolling] Calling _checkAndSync immediately');
    _checkAndSync();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  String _normalize(String? v) => (v ?? '').trim().replaceAll('"', '').toLowerCase();

  Future<void> _checkAndSync() async {
    print('[WifiPolling] ===== _checkAndSync called =====');
    try {
      String currentBssid = '';
      try {
        currentBssid = _normalize(await NetworkInfo().getWifiBSSID());
        print('[WifiPolling] Current BSSID: $currentBssid');
      } catch (e) {
        print('[WifiPolling] WiFi info read error: $e');
      }

      // Send BSSID to backend - backend handles verification and check-in/check-out
      print('[WifiPolling] Calling _postBssidToBackend');
      await _postBssidToBackend(currentBssid);

      try {
        onStatusUpdate?.call();
      } catch (e) {
        print('[WifiPolling] onStatusUpdate error: $e');
      }
    } catch (e) {
      print('[WifiPolling] _checkAndSync error: $e');
    }
  }

  Future<void> _postBssidToBackend(String bssid) async {
    try {
      print('[WifiPolling] ===== _postBssidToBackend called =====');
      print('[WifiPolling] BSSID: $bssid');
      print('[WifiPolling] Base URL: $baseUrl');
      print('[WifiPolling] Token: ${token.isNotEmpty ? "present" : "missing"}');

      final uri = Uri.parse('$baseUrl/api/thirdparty/employees/wifi-statusss');
      // Backend expects a simple body with only the BSSID
      final payload = {
        'bssid': bssid,
      };

      print('[WifiPolling] Request URL: $uri');
      print('[WifiPolling] Request payload: ${jsonEncode(payload)}');

      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json; charset=UTF-8',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      print('[WifiPolling] Response status: ${response.statusCode}');
      print('[WifiPolling] Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('[WifiPolling] BSSID sent to backend successfully: $bssid');
      } else {
        print('[WifiPolling] BSSID post failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[WifiPolling] _postBssidToBackend error: $e');
    }
  }
}