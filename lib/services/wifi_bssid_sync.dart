import 'dart:convert';
import 'dart:developer';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;

/// Shared WiFi BSSID read + backend sync used by foreground and background services.
class WifiBssidSync {
  static const Duration requestTimeout = Duration(seconds: 10);
  static const String wifiStatusPath = '/api/thirdparty/employees/wifi-statusss';

  static String normalize(String? value) =>
      (value ?? '').trim().replaceAll('"', '').toLowerCase();

  static Future<String> readCurrentBssid() async {
    try {
      return normalize(await NetworkInfo().getWifiBSSID());
    } catch (e) {
      log('[WifiBssidSync] Failed to read BSSID: $e');
      return '';
    }
  }

  /// POST current BSSID to backend. Returns true when the server accepts the payload.
  static Future<bool> postBssidToBackend({
    required String baseUrl,
    required String token,
    String? bssid,
  }) async {
    final resolvedBssid = bssid ?? await readCurrentBssid();

    try {
      final uri = Uri.parse('$baseUrl$wifiStatusPath');
      final payload = {'bssid': resolvedBssid};

      final response = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json; charset=UTF-8',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        log('[WifiBssidSync] Sync OK (bssid=$resolvedBssid)');
        return true;
      }

      log(
        '[WifiBssidSync] Sync failed ${response.statusCode}: ${response.body}',
      );
      return false;
    } catch (e) {
      log('[WifiBssidSync] Sync error: $e');
      return false;
    }
  }
}
