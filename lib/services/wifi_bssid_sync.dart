import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cnattendance/services/native_wifi_bssid.dart';

/// Shared WiFi BSSID read + backend sync used by foreground and background services.
class WifiBssidSync {
  static const Duration requestTimeout = Duration(seconds: 10);
  static const String wifiStatusPath = '/api/thirdparty/employees/wifi-statusss';
  static const String _cachedBssidKey = 'last_valid_bssid';

  static String normalize(String? value) =>
      (value ?? '').trim().replaceAll('"', '').toLowerCase();

  static bool isValidBssid(String bssid) {
    // Filter out dummy/invalid BSSIDs
    if (bssid.isEmpty) return false;
    if (bssid == '02:00:00:00:00:00') return false;
    if (bssid == '00:00:00:00:00:00') return false;
    // Check if it's a valid MAC address format
    final macRegex = RegExp(r'^([0-9a-f]{2}:){5}[0-9a-f]{2}$');
    return macRegex.hasMatch(bssid);
  }

  static Future<void> cacheBssid(String bssid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedBssidKey, bssid);
      log('[WifiBssidSync] Cached BSSID persistently: $bssid');
    } catch (e) {
      log('[WifiBssidSync] Failed to cache BSSID: $e');
    }
  }

  static Future<String?> _getCachedBssid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bssid = prefs.getString(_cachedBssidKey);
      
      if (bssid != null && isValidBssid(bssid)) {
        log('[WifiBssidSync] Using persistent cached BSSID: $bssid');
        return bssid;
      }
    } catch (e) {
      log('[WifiBssidSync] Failed to read cached BSSID: $e');
    }
    return null;
  }

  static Future<void> clearCachedBssid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedBssidKey);
      log('[WifiBssidSync] Persistent cached BSSID cleared');
    } catch (e) {
      log('[WifiBssidSync] Failed to clear cached BSSID: $e');
    }
  }

  static Future<String> readCurrentBssid() async {
    try {
      // Read BSSID using network_info_plus (works in both foreground and background)
      final bssid = normalize(await NativeWifiBssid.getWifiBssid());
      log('[WifiBssidSync] BSSID read: "$bssid"');
      
      if (isValidBssid(bssid)) {
        await cacheBssid(bssid);
        log('[WifiBssidSync] Using BSSID: $bssid');
        return bssid;
      }
      
      // If live read fails, try cached BSSID as fallback
      log('[WifiBssidSync] No valid BSSID from live read, trying cached BSSID');
      final cachedBssid = await _getCachedBssid();
      if (cachedBssid != null && isValidBssid(cachedBssid)) {
        log('[WifiBssidSync] Using cached BSSID as fallback: $cachedBssid');
        return cachedBssid;
      }
      
      log('[WifiBssidSync] No valid BSSID available');
      return '';
    } catch (e) {
      log('[WifiBssidSync] Failed to read BSSID: $e');
      try {
        final cachedBssid = await _getCachedBssid();
        if (cachedBssid != null && isValidBssid(cachedBssid)) {
          log('[WifiBssidSync] Using cached BSSID after error: $cachedBssid');
          return cachedBssid;
        }
      } catch (_) {}
      log('[WifiBssidSync] No valid BSSID available after error');
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

    // Skip sending if BSSID is invalid
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
      
      // Check if response is HTML error page instead of JSON
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
