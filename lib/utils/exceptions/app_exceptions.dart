/// Custom exception classes for better error handling throughout the app
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// API-related exceptions
class ApiException extends AppException {
  final int? statusCode;

  ApiException(String message,
      {this.statusCode, String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

/// Authentication exceptions
class AuthenticationException extends ApiException {
  AuthenticationException(String message, {dynamic originalError})
      : super(message,
            statusCode: 401, code: 'AUTH_ERROR', originalError: originalError);
}

/// Authorization exceptions (forbidden)
class AuthorizationException extends ApiException {
  AuthorizationException(String message, {dynamic originalError})
      : super(message,
            statusCode: 403, code: 'FORBIDDEN', originalError: originalError);
}

/// Resource not found exceptions
class NotFoundException extends ApiException {
  NotFoundException(String message, {dynamic originalError})
      : super(message,
            statusCode: 404, code: 'NOT_FOUND', originalError: originalError);
}

/// Server error exceptions
class ServerException extends ApiException {
  ServerException(String message, {int? statusCode, dynamic originalError})
      : super(message,
            statusCode: statusCode ?? 500,
            code: 'SERVER_ERROR',
            originalError: originalError);
}

/// Request timeout exceptions
class TimeoutException extends NetworkException {
  TimeoutException(String message, {dynamic originalError})
      : super(message, code: 'TIMEOUT', originalError: originalError);
}

/// Validation exceptions
class ValidationException extends AppException {
  final Map<String, List<String>>? errors;

  ValidationException(String message, {this.errors, dynamic originalError})
      : super(message, code: 'VALIDATION_ERROR', originalError: originalError);
}

/// Data parsing exceptions
class DataParseException extends AppException {
  DataParseException(String message, {dynamic originalError})
      : super(message, code: 'PARSE_ERROR', originalError: originalError);
}

/// No internet connection exception
class NoInternetException extends NetworkException {
  NoInternetException({dynamic originalError})
      : super(
            'No internet connection. Please check your network settings and try again.',
            code: 'NO_INTERNET',
            originalError: originalError);
}

/// Cache exceptions
class CacheException extends AppException {
  CacheException(String message, {dynamic originalError})
      : super(message, code: 'CACHE_ERROR', originalError: originalError);
}
