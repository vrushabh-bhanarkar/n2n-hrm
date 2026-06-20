import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:cnattendance/services/native_wifi_bssid.dart';

/// Shared WiFi BSSID read + backend sync used by foreground and background services.
class WifiBssidSync {
  static const Duration requestTimeout = Duration(seconds: 10);
  static const String wifiStatusPath = '/api/thirdparty/employees/wifi-statusss';

  static String normalize(String? value) =>
      (value ?? '').trim().replaceAll('"', '').toLowerCase();

  static bool isValidBssid(String bssid) {
    if (bssid.isEmpty) return false;
    if (bssid == '02:00:00:00:00:00') return false;
    if (bssid == '00:00:00:00:00:00') return false;
    final macRegex = RegExp(r'^([0-9a-f]{2}:){5}[0-9a-f]{2}$');
    return macRegex.hasMatch(bssid);
  }

  static Future<String> readCurrentBssid() async {
    try {
      final bssid = normalize(await NativeWifiBssid.getWifiBssid());
      log('[WifiBssidSync] BSSID read: "$bssid"');

      if (isValidBssid(bssid)) {
        log('[WifiBssidSync] Using BSSID: $bssid');
        return bssid;
      }

      log('[WifiBssidSync] No valid BSSID available');
      return '';
    } catch (e) {
      log('[WifiBssidSync] Failed to read BSSID: $e');
      return '';
    }
  }

  /// Send current BSSID to backend via POST request. Returns true when the server accepts the payload.
  static Future<bool> postBssidToBackend({
    required String baseUrl,
    required String token,
    String? bssid,
  }) async {
    log('[WifiBssidSync] postBssidToBackend called - baseUrl: $baseUrl, hasToken: ${token.isNotEmpty}');
    final resolvedBssid = bssid ?? await readCurrentBssid();

    if (!isValidBssid(resolvedBssid)) {
      log('[WifiBssidSync] Skipping sync - invalid BSSID: "$resolvedBssid"');
      return false;
    }

    try {
      final uri = Uri.parse('$baseUrl$wifiStatusPath');
      final payload = {'bssid': resolvedBssid};

      log('[WifiBssidSync] Sending POST request to: $uri with body: $payload');
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

      log('[WifiBssidSync] Response status: ${response.statusCode}, body: ${response.body}');

      final contentType = response.headers['content-type'] ?? '';
      final bodyLower = response.body.toLowerCase();
      final isHtmlError = contentType.contains('text/html') ||
                         bodyLower.contains('<!doctype') ||
                         bodyLower.contains('<html') ||
                         bodyLower.contains('404');

      if (isHtmlError) {
        log('[WifiBssidSync] Sync failed - received HTML error page instead of JSON (endpoint may not exist)');
        log('[WifiBssidSync] Response body (first 200 chars): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        return false;
      }

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
