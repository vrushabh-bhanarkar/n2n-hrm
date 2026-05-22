import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'exceptions/app_exceptions.dart';
import 'error_mapper.dart';

class AppErrorHandler {
  /// Handle any error and show appropriate message to user
  static void handleError(
    dynamic error, {
    BuildContext? context,
    http.Response? response,
    bool showToast = true,
    VoidCallback? onAuthError,
  }) {
    // Map error to AppException
    final appException = ErrorMapper.mapError(error, response: response);

    // Log technical details for debugging
    debugPrint('=== ERROR HANDLED ===');
    debugPrint(ErrorMapper.getTechnicalDetails(appException));
    debugPrint('====================');

    // Handle authentication errors specially
    if (appException is AuthenticationException && onAuthError != null) {
      onAuthError();
      return;
    }

    // Show error to user
    if (showToast) {
      _showErrorToUser(appException, context);
    }
  }

  /// Show error message to user
  static void _showErrorToUser(AppException exception, BuildContext? context) {
    final message = ErrorMapper.getUserMessage(exception);
    final color = _getErrorColor(exception);

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: Duration(seconds: exception is ServerException ? 5 : 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } else {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: color,
        textColor: Colors.white,
        fontSize: 14,
      );
    }
  }

  /// Get appropriate color for error type
  static Color _getErrorColor(AppException exception) {
    if (exception is AuthenticationException) {
      return Colors.red;
    } else if (exception is NetworkException || exception is NoInternetException) {
      return Colors.orange;
    } else if (exception is ServerException) {
      return Colors.deepOrange;
    } else if (exception is ValidationException) {
      return Colors.amber.shade700;
    } else {
      return Colors.red.shade700;
    }
  }

  /// Show a user-friendly error message for API connectivity issues
  static void showApiError(BuildContext? context) {
    handleError(
      NoInternetException(),
      context: context,
    );
  }

  /// Show error for authentication issues
  static void showAuthError(BuildContext? context) {
    handleError(
      AuthenticationException('Your session has expired. Please login again.'),
      context: context,
    );
  }

  /// Check if error indicates API connectivity issues
  static bool isApiConnectivityError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('api endpoint not found') ||
           errorString.contains('server returned html') ||
           errorString.contains('404') ||
           errorString.contains('connection') ||
           errorString.contains('network');
  }
}
