import 'dart:convert';
import 'dart:async';
import 'package:cnattendance/utils/http_client.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';

class LogoutStatusService {
  /// Backup polling endpoint to check logout approval status
  /// GET /api/logout-approval-status
  /// Uses the saved API base URL and Bearer token from Preferences
  static Future<Map<String, dynamic>?> checkLogoutApprovalStatus() async {
    try {
      final prefs = Preferences();
      final baseUrl = await prefs.getAppUrl();
      final token = await prefs.getToken();

      final response = await TimeoutHttpClient.get(
        Uri.parse('$baseUrl/api/logout-approval-status'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        timeout: Duration(seconds: 15), // Shorter timeout for status check
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } on TimeoutException {
      // Timeout is not critical for this check, return null
      print('⏱️ Logout status check timed out');
      return null;
    } catch (e) {
      return null;
    }
  }
}
