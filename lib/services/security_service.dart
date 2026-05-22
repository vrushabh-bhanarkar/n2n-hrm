import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to handle security-related operations using native Android platform channels
class SecurityService {
  static const _securityChannel = MethodChannel('com.n2nhrm.apk.security');

  /// Disable screenshots and screen recordings on Android using FLAG_SECURE
  static Future<void> disableScreenshots() async {
    if (!Platform.isAndroid) return;

    try {
      final result = await _securityChannel.invokeMethod('setFlagSecure');
      if (kDebugMode) {
        debugPrint('✅ Screenshot capture disabled via FLAG_SECURE: $result');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PlatformException setting FLAG_SECURE: ${e.code} - ${e.message}');
      }
      // Continue app execution even if setting FLAG_SECURE fails
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Exception setting FLAG_SECURE: $e');
      }
      // Continue app execution even if setting FLAG_SECURE fails
    }
  }
}

