import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResponseHandler {
  /// Safely parses HTTP response and handles common error cases
  static dynamic parseResponse(http.Response response) {
    // Note: API logging is now handled by ApiLogger in logging_middleware
    // No need to print here as it will be duplicated

    final lowerBody = response.body.toLowerCase();

    if (response.isRedirect || response.statusCode == 302) {
      throw "Backend redirected the request (HTTP ${response.statusCode}). The HRM server may be unavailable or suspended.";
    }

    if (lowerBody.contains('account suspended')) {
      throw "The HRM backend account is suspended. Contact your hosting provider or system administrator.";
    }

    // Check if response is HTML (404/error page) instead of JSON
    if (response.body.trim().startsWith('<!DOCTYPE html>') ||
        response.body.trim().startsWith('<html')) {
      throw "Backend returned HTML instead of JSON. The server may be down, suspended, or misconfigured.";
    }

    // Check for empty response
    if (response.body.trim().isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {}; // Return empty object for successful empty responses
      } else {
        throw "Empty response received with status code ${response.statusCode}";
      }
    }

    try {
      return json.decode(response.body);
    } catch (e) {
      // Error logging is handled by ApiLogger in logging_middleware
      throw "Invalid JSON response: ${e.toString()}";
    }
  }

  /// Check if response indicates authentication failure
  static bool isAuthError(http.Response response) {
    return response.statusCode == 401;
  }

  /// Check if response indicates server error
  static bool isServerError(http.Response response) {
    return response.statusCode >= 500;
  }

  /// Check if response indicates client error (4xx)
  static bool isClientError(http.Response response) {
    return response.statusCode >= 400 && response.statusCode < 500;
  }

  /// Check if response is successful
  static bool isSuccessful(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Get user-friendly error message
  static String getErrorMessage(http.Response response) {
    try {
      final data = parseResponse(response);
      if (data is Map && data.containsKey('message')) {
        return data['message'].toString();
      }
    } catch (e) {
      // If we can't parse the response, return a generic message
    }

    switch (response.statusCode) {
      case 400:
        return 'Bad request. Please check your input.';
      case 401:
        return 'Authentication failed. Please login again.';
      case 403:
        return 'Access denied. You don\'t have permission for this action.';
      case 404:
        return 'Resource not found. Please contact support.';
      case 408:
        return 'Request timeout. Please check your internet connection.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
        return 'Service temporarily unavailable. Please try again.';
      case 503:
        return 'Service unavailable. Please try again later.';
      default:
        return 'Network error (${response.statusCode}). Please check your connection.';
    }
  }
}
