import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Custom HTTP client with timeout handling and error management
/// This prevents the app from getting stuck when APIs don't respond
class TimeoutHttpClient {
  // Default timeout durations
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 2);
  static const Duration downloadTimeout = Duration(minutes: 3);

  /// GET request with timeout
  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(
            timeout ?? defaultTimeout,
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout - Server took too long to respond',
                timeout ?? defaultTimeout,
              );
            },
          );
      return response;
    } on TimeoutException catch (e) {
      if (kDebugMode) print('⏱️ GET Timeout: ${url.toString()} - $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) print('❌ GET Error: ${url.toString()} - $e');
      rethrow;
    }
  }

  /// POST request with timeout
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(
            timeout ?? defaultTimeout,
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout - Server took too long to respond',
                timeout ?? defaultTimeout,
              );
            },
          );
      return response;
    } on TimeoutException catch (e) {
      if (kDebugMode) print('⏱️ POST Timeout: ${url.toString()} - $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) print('❌ POST Error: ${url.toString()} - $e');
      rethrow;
    }
  }

  /// PUT request with timeout
  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    try {
      final response = await http
          .put(url, headers: headers, body: body)
          .timeout(
            timeout ?? defaultTimeout,
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout - Server took too long to respond',
                timeout ?? defaultTimeout,
              );
            },
          );
      return response;
    } on TimeoutException catch (e) {
      if (kDebugMode) print('⏱️ PUT Timeout: ${url.toString()} - $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) print('❌ PUT Error: ${url.toString()} - $e');
      rethrow;
    }
  }

  /// DELETE request with timeout
  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    try {
      final response = await http
          .delete(url, headers: headers, body: body)
          .timeout(
            timeout ?? defaultTimeout,
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout - Server took too long to respond',
                timeout ?? defaultTimeout,
              );
            },
          );
      return response;
    } on TimeoutException catch (e) {
      if (kDebugMode) print('⏱️ DELETE Timeout: ${url.toString()} - $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) print('❌ DELETE Error: ${url.toString()} - $e');
      rethrow;
    }
  }

  /// PATCH request with timeout
  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    try {
      final response = await http
          .patch(url, headers: headers, body: body)
          .timeout(
            timeout ?? defaultTimeout,
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout - Server took too long to respond',
                timeout ?? defaultTimeout,
              );
            },
          );
      return response;
    } on TimeoutException catch (e) {
      if (kDebugMode) print('⏱️ PATCH Timeout: ${url.toString()} - $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) print('❌ PATCH Error: ${url.toString()} - $e');
      rethrow;
    }
  }

  /// Helper method to handle common error responses
  static String getErrorMessage(dynamic error) {
    if (error is TimeoutException) {
      return 'Connection timeout. Please check your internet and try again.';
    } else if (error.toString().contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    } else if (error.toString().contains('HandshakeException')) {
      return 'Security error. Please try again.';
    } else if (error.toString().contains('FormatException')) {
      return 'Invalid server response. Please try again.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }
}
