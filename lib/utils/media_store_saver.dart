import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MediaStoreSaver {
  MediaStoreSaver._();

  static const MethodChannel _channel = MethodChannel('com.n2nhrm.apk.media');

  static Future<String?> saveImage(
    Uint8List bytes,
    String filename, {
    String mimeType = 'image/jpeg',
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('saveImageToMediaStore', {
        'bytes': bytes,
        'filename': filename,
        'mimeType': mimeType,
      });
    } catch (e) {
      debugPrint('MediaStore save failed: $e');
      return null;
    }
  }

  static Future<String?> saveFile(
    Uint8List bytes,
    String filename, {
    String mimeType = 'application/octet-stream',
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('saveFileToMediaStore', {
        'bytes': bytes,
        'filename': filename,
        'mimeType': mimeType,
      });
    } catch (e) {
      debugPrint('MediaStore save failed: $e');
      return null;
    }
  }
}
