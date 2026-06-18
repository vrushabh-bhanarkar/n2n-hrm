import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_storage/get_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

  static Future<void> _cacheBssid(String bssid) async {
    try {
      final storage = GetStorage();
      await storage.write(_cachedBssidKey, bssid);
      log('[WifiBssidSync] Cached BSSID persistently: $bssid');
    } catch (e) {
      log('[WifiBssidSync] Failed to cache BSSID: $e');
    }
  }

  static Future<String?> _getCachedBssid() async {
    try {
      final storage = GetStorage();
      final bssid = storage.read(_cachedBssidKey);
      
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
      final storage = GetStorage();
      await storage.remove(_cachedBssidKey);
      log('[WifiBssidSync] Persistent cached BSSID cleared');
    } catch (e) {
      log('[WifiBssidSync] Failed to clear cached BSSID: $e');
    }
  }

  static Future<String> readCurrentBssid() async {
    try {
      final bssid = normalize(await NetworkInfo().getWifiBSSID());
      log('[WifiBssidSync] Raw BSSID read: "$bssid"');
      
      if (isValidBssid(bssid)) {
        // Check if BSSID changed from cached value
        final cachedBssid = await _getCachedBssid();
        if (cachedBssid != null && cachedBssid != bssid) {
          log('[WifiBssidSync] BSSID changed from $cachedBssid to $bssid, updating cache');
        }
        
        // Cache the valid BSSID persistently for future use
        await _cacheBssid(bssid);
        log('[WifiBssidSync] Using current BSSID: $bssid');
        return bssid;
      }
      
      log('[WifiBssidSync] Invalid BSSID detected: "$bssid", checking WiFi connectivity');
      
      // If OS blocked BSSID read (02:00:00:00:00:00), verify if still on WiFi
      final connectivityResult = await Connectivity().checkConnectivity();
      final isWifiConnected = connectivityResult.contains(ConnectivityResult.wifi);
      
      if (isWifiConnected) {
        // Use persistent cached BSSID as fallback (no time expiry)
        final cachedBssid = await _getCachedBssid();
        if (cachedBssid != null) {
          log('[WifiBssidSync] OS restricted BSSID. Using persistent fallback: $cachedBssid');
          return cachedBssid;
        }
      } else {
        log('[WifiBssidSync] WiFi not connected, no fallback available');
      }
      
      log('[WifiBssidSync] No valid BSSID available');
      return '';
    } catch (e) {
      log('[WifiBssidSync] Failed to read BSSID: $e, trying cached value');
      
      // Try to use cached BSSID as fallback
      final cachedBssid = await _getCachedBssid();
      if (cachedBssid != null) {
        log('[WifiBssidSync] Using cached BSSID: $cachedBssid');
        return cachedBssid;
      }
      
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
