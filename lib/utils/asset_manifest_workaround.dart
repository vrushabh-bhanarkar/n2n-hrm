import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_translate/flutter_translate.dart';

/// Workaround for flutter_translate incompatibility with Flutter 3.41.4
/// Flutter 3.41.4 generates binary AssetManifest.bin instead of JSON
/// This utility provides a helper to manually load localization files
class AssetManifestWorkaround {
  static const List<String> supportedLocales = [
    'en_US',
    'ar',
    'es',
    'ne',
    'fa',
    'in',
    'pt',
    'ru',
    'de',
    'tr',
    'fr',
  ];

  static const Map<String, String> localeFileMap = {
    'en_US': 'assets/i18n/en.json',
    'ar': 'assets/i18n/ar.json',
    'de': 'assets/i18n/de.json',
    'es': 'assets/i18n/es.json',
    'fa': 'assets/i18n/fa.json',
    'fr': 'assets/i18n/fr.json',
    'in': 'assets/i18n/in.json',
    'ne': 'assets/i18n/ne.json',
    'pt': 'assets/i18n/pt.json',
    'ru': 'assets/i18n/ru.json',
    'tr': 'assets/i18n/tr.json',
  };

  /// Generate mock AssetManifest.json content that lists all locale files
  static String generateAssetManifestJson() {
    return jsonEncode({
      'assets': [
        ...localeFileMap.values,
        'assets/icons/hrm-icon.png',
        'assets/fonts/google_sans.ttf',
        'assets/images/',
        'assets/sound/',
        'assets/ca/',
        'assets/raw/',
      ]
    });
  }

  /// Create a custom LocalizationDelegate that handles the missing manifest
  /// This is not used directly but documents the intended fix
  static void installWorkaround() {
    // No-op for now - we'll handle this in main.dart instead
    // by wrapping the LocalizationDelegate.create call in a try-catch
  }
}
