/// Example usage of the new error handling system
/// 
/// This guide shows how to properly handle errors in your repositories and providers
///
/// NOTE: This file contains documentation examples only and is not meant to be imported
/// or executed. It serves as a reference guide for developers.

// ignore_for_file: unused_import, unused_local_variable, dead_code, unreachable_from_main
// ignore_for_file: undefined_class, undefined_identifier, invalid_override_of_non_virtual_member

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cnattendance/utils/exceptions/app_exceptions.dart';
import 'package:cnattendance/utils/error_mapper.dart';
import 'package:cnattendance/utils/app_error_handler.dart';
import 'package:cnattendance/data/source/network/api_helper.dart';
import 'package:cnattendance/utils/constant.dart';

// ============================================================================
// REPOSITORY EXAMPLE - Old vs New Approach
// ============================================================================

/// ❌ OLD APPROACH (Avoid this)
class OldRepository {
  Future<Map<String, dynamic>> getData() async {
    try {
      final response = await http.get(Uri.parse('api_url'));
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return data;
      } else {
        var errorMessage = data['message'];
        throw errorMessage; // ❌ Throwing raw strings
      }
    } catch (e) {
      throw unknownError(e); // ❌ Using deprecated function
    }
  }
}

/// ✅ NEW APPROACH (Use this)
class NewRepository {
  // METHOD 1: Using ApiHelper (Recommended for simple cases)
  Future<Map<String, dynamic>> getDataSimple(String url, Map<String, String> headers) async {
    try {
      return await ApiHelper.get(url, headers);
    } catch (e) {
      // Re-throw as AppException if not already
      if (e is AppException) {
        rethrow;
      }
      throw ErrorMapper.mapError(e);
    }
  }

  // METHOD 2: Manual handling with proper error mapping (More control)
  Future<Map<String, dynamic>> getDataManual(String url, Map<String, String> headers) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      
      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE html>')) {
        throw ErrorMapper.mapError('Server error', response: response);
      }

      // Parse response
      final data = json.decode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        // This will throw appropriate AppException based on status code
        throw ErrorMapper.mapError(data, response: response);
      }
    } on SocketException catch (e) {
      // Network error
      throw ErrorMapper.mapError(e);
    } on FormatException catch (e) {
      // JSON parsing error
      throw ErrorMapper.mapError(e);
    } catch (e) {
      // Any other error
      throw ErrorMapper.mapError(e);
    }
  }

  // METHOD 3: For multipart/form-data requests
  Future<Map<String, dynamic>> uploadData(
    String url,
    Map<String, String> headers,
    Map<String, String> fields,
  ) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(headers);
      request.fields.addAll(fields);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      final data = json.decode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        throw ErrorMapper.mapError(data, response: response);
      }
    } catch (e) {
      throw ErrorMapper.mapError(e);
    }
  }
}

// ============================================================================
// PROVIDER/CONTROLLER EXAMPLE - Old vs New Approach
// ============================================================================

/// ❌ OLD APPROACH
class OldProvider {
  Future<void> loadDataOld() async {
    try {
      final data = await repository.getData();
      // Process data...
    } catch (e) {
      print('Error: $e'); // ❌ Just printing
      showToast(e.toString()); // ❌ Showing raw error
    }
  }
}

/// ✅ NEW APPROACH
class NewProvider {
  Future<void> loadDataNew(BuildContext? context) async {
    try {
      final data = await repository.getData();
      // Process data...
    } on AuthenticationException catch (e) {
      // Handle auth error specifically - maybe logout
      AppErrorHandler.handleError(
        e,
        context: context,
        onAuthError: () {
          // Navigate to login screen
          // clearUserData();
        },
      );
    } on NetworkException catch (e) {
      // Handle network error
      AppErrorHandler.handleError(e, context: context);
    } on AppException catch (e) {
      // Handle any other app exception
      AppErrorHandler.handleError(e, context: context);
    } catch (e) {
      // Fallback for any unexpected error
      AppErrorHandler.handleError(
        ErrorMapper.mapError(e),
        context: context,
      );
    }
  }

  // Shorter version if you don't need specific handling
  Future<void> loadDataSimple(BuildContext? context) async {
    try {
      final data = await repository.getData();
      // Process data...
    } catch (e) {
      AppErrorHandler.handleError(
        ErrorMapper.mapError(e),
        context: context,
      );
    }
  }
}

// ============================================================================
// WIDGET/SCREEN EXAMPLE - Old vs New Approach
// ============================================================================

/// ❌ OLD APPROACH
void loadDataOldWidget(BuildContext context, dynamic provider) async {
  try {
    await provider.loadData();
  } catch (e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(e.toString()), // ❌ Raw error to user
      ),
    );
  }
}

/// ✅ NEW APPROACH
void loadDataNewWidget(BuildContext context, dynamic provider) async {
  try {
    await provider.loadData();
  } catch (e) {
    // Error is already handled by provider
    // Or handle it here if needed:
    AppErrorHandler.handleError(
      ErrorMapper.mapError(e),
      context: context,
    );
  }
}

// ============================================================================
// CUSTOM EXCEPTION THROWING
// ============================================================================

class ExampleService {
  /// Throw specific exceptions when you know the error type
  Future<void> validateData(String data) async {
    if (data.isEmpty) {
      throw ValidationException(
        'Data cannot be empty',
        errors: {'data': ['This field is required']},
      );
    }
    
    if (data.length < 3) {
      throw ValidationException(
        'Data must be at least 3 characters',
      );
    }
  }

  /// Handle timeout scenarios
  Future<void> fetchWithTimeout() async {
    try {
      await Future.delayed(Duration(seconds: 30));
      // Make request...
    } on TimeoutException catch (e) {
      throw ErrorMapper.mapError(e);
    }
  }
}

// ============================================================================
// MIGRATION CHECKLIST
// ============================================================================

/*
STEP-BY-STEP MIGRATION GUIDE:

1. Update Repository Methods:
   ✅ Replace unknownError() calls with ErrorMapper.mapError()
   ✅ Catch specific exception types (SocketException, FormatException, etc.)
   ✅ Throw AppException types instead of raw strings
   ✅ Use ApiHelper for simple GET/POST requests

2. Update Provider/Controller Methods:
   ✅ Catch AppException types specifically
   ✅ Use AppErrorHandler.handleError() to show errors to users
   ✅ Handle AuthenticationException specially (logout, navigate to login)
   ✅ Remove print() statements for errors (use debugPrint if needed)

3. Update UI/Widgets:
   ✅ Remove manual error dialogs
   ✅ Let AppErrorHandler show errors via SnackBar/Toast
   ✅ Add onAuthError callbacks where needed

4. Remove Deprecated Code:
   ✅ Remove unknownError() function calls
   ✅ Remove manual error message extraction
   ✅ Remove raw string throws

5. Testing:
   ✅ Test network errors (turn off wifi)
   ✅ Test authentication errors (invalid token)
   ✅ Test server errors (500, 502, etc.)
   ✅ Test validation errors (400, 422)
   ✅ Test timeout scenarios

6. Benefits:
   ✅ Consistent error messages across the app
   ✅ Better error logging for debugging
   ✅ User-friendly error messages
   ✅ Proper error categorization
   ✅ Easier to maintain and extend
*/
