import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'exceptions/app_exceptions.dart';

/// Maps various error types to user-friendly AppException instances
class ErrorMapper {
  /// Map any exception to an appropriate AppException
  static AppException mapError(dynamic error, {http.Response? response}) {
    // If it's already an AppException, return it
    if (error is AppException) {
      return error;
    }

    // Handle HTTP response errors
    if (response != null) {
      return _mapHttpError(response, error);
    }

    // Handle socket exceptions (network errors)
    if (error is SocketException) {
      return NoInternetException();
    }

    // Handle HTTP client transport failures (DNS lookup, connection abort, etc.)
    if (error is http.ClientException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('failed host lookup') ||
          msg.contains('socketexception') ||
          msg.contains('connection abort') ||
          msg.contains('connection reset') ||
          msg.contains('network is unreachable')) {
        return NoInternetException(originalError: error);
      }
      return NetworkException(
        'Network error. Please check your connection and try again.',
        originalError: error,
      );
    }

    // Handle timeout exceptions
    if (error is TimeoutException || error is HandshakeException) {
      return TimeoutException(
        'Request timed out. Please check your internet connection and try again.',
        originalError: error,
      );
    }

    // Handle format exceptions (JSON parsing errors)
    if (error is FormatException) {
      return DataParseException(
        'Invalid data format received from server.',
        originalError: error,
      );
    }

    // Handle string errors (legacy error handling)
    if (error is String) {
      // Check for known error patterns
      if (_isAuthError(error)) {
        return AuthenticationException(
          'Your session has expired. Please login again.',
          originalError: error,
        );
      }
      if (_isNetworkError(error)) {
        return NetworkException(
          'Network error. Please check your connection and try again.',
          originalError: error,
        );
      }
      if (_isServerError(error)) {
        return ServerException(
          'Server error. Please try again later.',
          originalError: error,
        );
      }
      // Return generic exception with the string message
      return AppException(error, originalError: error);
    }

    // Handle Exception types
    if (error is Exception) {
      final errorString = error.toString();
      // Remove "Exception: " prefix if present
      final cleanMessage = errorString.replaceFirst('Exception: ', '');
      
      if (_isAuthError(cleanMessage)) {
        return AuthenticationException(
          'Your session has expired. Please login again.',
          originalError: error,
        );
      }
      
      return AppException(
        cleanMessage.isNotEmpty ? cleanMessage : 'An unexpected error occurred.',
        originalError: error,
      );
    }

    // Handle map/object errors
    if (error is Map) {
      final message = error['message']?.toString() ?? 
                     error['error']?.toString() ?? 
                     'An error occurred';
      return AppException(message, originalError: error);
    }

    // Default fallback
    return AppException(
      'An unexpected error occurred. Please try again.',
      originalError: error,
    );
  }

  /// Map HTTP response to appropriate exception
  static AppException _mapHttpError(http.Response response, dynamic originalError) {
    final statusCode = response.statusCode;
    String message = _extractErrorMessage(response);

    switch (statusCode) {
      case 400:
        return ValidationException(
          message.isEmpty ? 'Invalid request. Please check your input.' : message,
          originalError: originalError,
        );

      case 401:
        return AuthenticationException(
          message.isEmpty ? 'Your session has expired. Please login again.' : message,
          originalError: originalError,
        );

      case 403:
        return AuthorizationException(
          message.isEmpty
              ? 'Access denied. You don\'t have permission for this action.'
              : message,
          originalError: originalError,
        );

      case 404:
        return NotFoundException(
          message.isEmpty
              ? 'The requested resource was not found.'
              : message,
          originalError: originalError,
        );

      case 408:
        return TimeoutException(
          'Request timeout. Please check your internet connection.',
          originalError: originalError,
        );

      case 422:
        // Try to extract validation errors
        Map<String, List<String>>? validationErrors;
        try {
          final data = json.decode(response.body);
          if (data is Map && data.containsKey('errors')) {
            validationErrors = _parseValidationErrors(data['errors']);
          }
        } catch (e) {
          debugPrint('Failed to parse validation errors: $e');
        }
        return ValidationException(
          message.isEmpty ? 'Validation failed. Please check your input.' : message,
          errors: validationErrors,
          originalError: originalError,
        );

      case 429:
        return ApiException(
          'Too many requests. Please try again later.',
          statusCode: 429,
          code: 'RATE_LIMIT',
          originalError: originalError,
        );

      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          message.isEmpty
              ? 'Server error. Please try again later.'
              : message,
          statusCode: statusCode,
          originalError: originalError,
        );

      default:
        if (statusCode >= 400 && statusCode < 500) {
          return ApiException(
            message.isEmpty
                ? 'Request failed. Please try again.'
                : message,
            statusCode: statusCode,
            originalError: originalError,
          );
        } else if (statusCode >= 500) {
          return ServerException(
            message.isEmpty
                ? 'Server error. Please try again later.'
                : message,
            statusCode: statusCode,
            originalError: originalError,
          );
        } else {
          return ApiException(
            message.isEmpty
                ? 'An unexpected error occurred.'
                : message,
            statusCode: statusCode,
            originalError: originalError,
          );
        }
    }
  }

  /// Extract error message from HTTP response
  static String _extractErrorMessage(http.Response response) {
    try {
      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE html>') ||
          response.body.trim().startsWith('<html')) {
        return 'Server error. Please contact support.';
      }

      // Check for empty response
      if (response.body.trim().isEmpty) {
        return '';
      }

      // Try to parse JSON
      final data = json.decode(response.body);
      
      if (data is Map) {
        // Try multiple common message fields
        return data['message']?.toString() ??
            data['error']?.toString() ??
            data['msg']?.toString() ??
            '';
      }
    } catch (e) {
      debugPrint('Failed to extract error message: $e');
    }
    return '';
  }

  /// Parse validation errors from API response
  static Map<String, List<String>> _parseValidationErrors(dynamic errors) {
    final Map<String, List<String>> validationErrors = {};
    
    if (errors is Map) {
      errors.forEach((key, value) {
        if (value is List) {
          validationErrors[key.toString()] = 
              value.map((e) => e.toString()).toList();
        } else {
          validationErrors[key.toString()] = [value.toString()];
        }
      });
    }
    
    return validationErrors;
  }

  /// Check if error string indicates authentication error
  static bool _isAuthError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('unauthenticated') ||
        lowerError.contains('unauthorized') ||
        lowerError.contains('session expired') ||
        lowerError.contains('token') ||
        lowerError.contains('authentication failed');
  }

  /// Check if error string indicates network error
  static bool _isNetworkError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('socket') ||
        lowerError.contains('failed host lookup') ||
        lowerError.contains('timeout');
  }

  /// Check if error string indicates server error
  static bool _isServerError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('server error') ||
        lowerError.contains('internal server') ||
        lowerError.contains('500') ||
        lowerError.contains('502') ||
        lowerError.contains('503');
  }

  /// Get user-friendly message from AppException
  static String getUserMessage(AppException exception) {
    // Return the exception message directly
    // It's already user-friendly due to our mapping
    return exception.message;
  }

  /// Get technical details for logging
  static String getTechnicalDetails(AppException exception) {
    final buffer = StringBuffer();
    buffer.writeln('Error Type: ${exception.runtimeType}');
    buffer.writeln('Message: ${exception.message}');
    
    if (exception.code != null) {
      buffer.writeln('Code: ${exception.code}');
    }
    
    if (exception is ApiException && exception.statusCode != null) {
      buffer.writeln('Status Code: ${exception.statusCode}');
    }
    
    if (exception is ValidationException && exception.errors != null) {
      buffer.writeln('Validation Errors: ${exception.errors}');
    }
    
    if (exception.originalError != null) {
      buffer.writeln('Original Error: ${exception.originalError}');
    }
    
    return buffer.toString();
  }
}
