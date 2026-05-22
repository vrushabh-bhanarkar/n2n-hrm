import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Centralized API logging utility with clean, organized output
class ApiLogger {
  static const String _separator = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  static bool _isEnabled = true;

  /// Enable or disable API logging
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Check if logging is enabled
  static bool get isEnabled => _isEnabled;

  /// Log API request with clean formatting
  static void logRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
  }) {
    if (!_isEnabled || !kDebugMode) return;

    // Print each section separately to avoid truncation
    // Using print() instead of debugPrint() to ensure visibility
    print('\n$_separator');
    print('📤 API REQUEST');
    print(_separator);
    print('🔹 Method: $method');
    print('🔹 URL: $url');

    if (headers != null && headers.isNotEmpty) {
      print('🔹 Headers:');
      headers.forEach((key, value) {
        // Mask sensitive headers
        if (key.toLowerCase() == 'authorization') {
          print('   • $key: ${_maskToken(value)}');
        } else {
          print('   • $key: $value');
        }
      });
    }

    if (body != null) {
      print('🔹 Body:');
      final formattedBody = _formatJson(body);
      // Split long body into chunks to avoid truncation
      _printLongString(formattedBody);
    }

    print(_separator);
  }

  /// Log API response with clean formatting
  static void logResponse({
    required String method,
    required String url,
    required int statusCode,
    required String responseBody,
    Map<String, String>? headers,
  }) {
    if (!_isEnabled || !kDebugMode) return;

    // Print each section separately to avoid truncation
    // Using print() instead of debugPrint() to ensure visibility
    print('\n$_separator');

    // Color code based on status
    if (statusCode >= 200 && statusCode < 300) {
      print('✅ API RESPONSE - SUCCESS');
    } else if (statusCode >= 400 && statusCode < 500) {
      print('⚠️ API RESPONSE - CLIENT ERROR');
    } else if (statusCode >= 500) {
      print('❌ API RESPONSE - SERVER ERROR');
    } else {
      print('📥 API RESPONSE');
    }

    print(_separator);
    print('🔹 Method: $method');
    print('🔹 URL: $url');
    print('🔹 Status Code: $statusCode');

    if (headers != null && headers.isNotEmpty) {
      print('🔹 Response Headers:');
      headers.forEach((key, value) {
        print('   • $key: $value');
      });
    }

    print('🔹 Response Body:');
    final formattedBody = _formatJson(responseBody);
    // Split long body into chunks to avoid truncation
    _printLongString(formattedBody);
    print(_separator);
  }

  /// Log API error with clean formatting
  static void logError({
    required String method,
    required String url,
    required dynamic error,
    StackTrace? stackTrace,
  }) {
    if (!_isEnabled || !kDebugMode) return;

    // Print each section separately to avoid truncation
    // Using print() instead of debugPrint() to ensure visibility
    print('\n$_separator');
    print('❌ API ERROR');
    print(_separator);
    print('🔹 Method: $method');
    print('🔹 URL: $url');
    print('🔹 Error: $error');

    if (stackTrace != null && kDebugMode) {
      print('🔹 Stack Trace:');
      final stackLines = stackTrace.toString().split('\n').take(5).join('\n');
      _printLongString(stackLines);
    }

    print(_separator);
  }

  /// Helper method to print long strings in chunks to avoid truncation
  static void _printLongString(String text) {
    final pattern = RegExp('.{1,800}'); // chunk size
    pattern.allMatches(text).forEach((match) {
      print(match.group(0));
    });
  }

  /// Format JSON for readable output
  static String _formatJson(dynamic data) {
    try {
      if (data == null) return '   (empty)';

      // If it's already a string, try to parse it
      dynamic jsonData = data;
      if (data is String) {
        try {
          jsonData = json.decode(data);
        } catch (_) {
          // If parsing fails, return as is (might not be JSON)
          return '   ${data.length > 500 ? data.substring(0, 500) + '...' : data}';
        }
      }

      // Pretty print JSON
      const encoder = JsonEncoder.withIndent('   ');
      String formatted = encoder.convert(jsonData);

      // Limit length if too long
      if (formatted.length > 2000) {
        return '${formatted.substring(0, 2000)}\n   ... (truncated, ${formatted.length} total characters)';
      }

      return formatted;
    } catch (e) {
      return '   $data';
    }
  }

  /// Mask authorization token for security
  static String _maskToken(String token) {
    if (token.isEmpty) return '(empty)';
    if (token.length < 20) return 'Bearer ****';

    final parts = token.split(' ');
    if (parts.length == 2 && parts[0] == 'Bearer') {
      final tokenValue = parts[1];
      if (tokenValue.length > 10) {
        return 'Bearer ${tokenValue.substring(0, 8)}...${tokenValue.substring(tokenValue.length - 4)}';
      }
    }

    return token.substring(0, 10) + '...' + token.substring(token.length - 4);
  }

  /// Clear console (useful for debugging)
  static void clearConsole() {
    print('\n\n\n\n\n\n\n\n\n\n');
  }

  /// Log a custom message with formatting
  static void log(String message, {String emoji = '📝'}) {
    if (!_isEnabled || !kDebugMode) return;
    print('$emoji $message');
  }

  /// Log screen navigation
  static void logNavigation(String screenName) {
    if (!_isEnabled || !kDebugMode) return;
    print('\n🔄 NAVIGATION → $screenName\n');
  }
}
