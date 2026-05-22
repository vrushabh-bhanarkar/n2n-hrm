import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cnattendance/utils/exceptions/app_exceptions.dart';
import 'package:cnattendance/utils/error_mapper.dart';

/// Helper functions for making API calls with proper error handling
class ApiHelper {
  /// Make a GET request with error handling
  static Future<Map<String, dynamic>> get(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      return _handleResponse(response);
    } catch (e) {
      throw ErrorMapper.mapError(e);
    }
  }

  /// Make a POST request with error handling
  static Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
    String? encodedBody,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: encodedBody ?? (body != null ? json.encode(body) : null),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ErrorMapper.mapError(e);
    }
  }

  /// Make a PUT request with error handling
  static Future<Map<String, dynamic>> put(
    String url,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw ErrorMapper.mapError(e);
    }
  }

  /// Make a DELETE request with error handling
  static Future<Map<String, dynamic>> delete(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final response = await http.delete(Uri.parse(url), headers: headers);
      return _handleResponse(response);
    } catch (e) {
      throw ErrorMapper.mapError(e);
    }
  }

  /// Handle HTTP response and throw appropriate exceptions
  static Map<String, dynamic> _handleResponse(http.Response response) {
    // Check if response is HTML (404/error page)
    if (response.body.trim().startsWith('<!DOCTYPE html>') ||
        response.body.trim().startsWith('<html')) {
      throw ErrorMapper.mapError(
        'Server returned HTML instead of JSON',
        response: response,
      );
    }

    // Check for empty response
    if (response.body.trim().isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {}; // Success with empty body
      } else {
        throw ErrorMapper.mapError(
          'Empty response from server',
          response: response,
        );
      }
    }

    // Try to parse JSON
    Map<String, dynamic> data;
    try {
      data = json.decode(response.body);
    } catch (e) {
      throw DataParseException(
        'Failed to parse server response',
        originalError: e,
      );
    }

    // Check status code
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      // Throw appropriate exception based on status code
      throw ErrorMapper.mapError(data, response: response);
    }
  }

  /// Extract error message from response data
  static String extractErrorMessage(Map<String, dynamic> data,
      {String defaultMessage = 'An error occurred'}) {
    return data['message']?.toString() ??
        data['error']?.toString() ??
        data['msg']?.toString() ??
        defaultMessage;
  }

  /// Check if response indicates success
  static bool isSuccess(Map<String, dynamic> data) {
    // Check various success indicators
    if (data.containsKey('success')) {
      return data['success'] == true;
    }
    if (data.containsKey('status')) {
      final status = data['status'];
      return status == true || status == 'success' || status == 200;
    }
    // If no explicit success indicator, assume success if no error
    return !data.containsKey('error');
  }
}
