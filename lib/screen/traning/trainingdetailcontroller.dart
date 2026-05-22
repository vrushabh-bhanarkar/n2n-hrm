import 'dart:io';
import 'dart:typed_data';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/trainingresponse/trainingresponse.dart';
import 'package:cnattendance/repositories/trainingrepository.dart';
import 'package:cnattendance/utils/media_store_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class TrainingDetailController extends GetxController {
  final repository = TrainingRepository();
  var upcomingTrainingList = <Training>[].obs;
  var pastTrainingList = <Training>[].obs;
  int upcomingPage = 1;
  int pastPage = 1;

  var toggleValue = 0.obs;

  Future<bool> checkAndRequestStoragePermission() async {
    var status = await Permission.photos.status;
    if (!status.isGranted) {
      status = await Permission.photos.request();
    }

    return status.isGranted;
  }

  Future<void> saveFileLocally(String url) async {
    try {
      // Handle relative URLs by prefixing base app URL
      String fullUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        final prefs = Preferences();
        final base = await prefs.getAppUrl();
        fullUrl = base + url;
      }

      final uri = Uri.parse(fullUrl);
      final filename = _resolveFilename(uri, isImage: true);

      // Request storage permission on Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            Get.snackbar('Permission denied', 'Storage permission is required to download files', snackPosition: SnackPosition.BOTTOM);
            return;
          }
        }
      }

      Preferences _prefs = Preferences();
      String _token = await _prefs.getToken();
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json'
      });
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      // If image, save to gallery
      final lower = filename.toLowerCase();
      final isImage = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.bmp') || lower.endsWith('.heic');

      if (isImage) {
        final Uint8List bytes = response.bodyBytes;
        final mediaStorePath = await MediaStoreSaver.saveImage(bytes, filename);
        if (mediaStorePath != null) {
          Get.snackbar('Download complete', 'Saved to gallery: $mediaStorePath', snackPosition: SnackPosition.BOTTOM);
          return;
        }

        // If MediaStore failed, write to Downloads as fallback
        final fallbackPath = await _saveBytesToFile(bytes, filename);
        if (fallbackPath != null) {
          Get.snackbar('Download complete', 'Saved to $fallbackPath', snackPosition: SnackPosition.BOTTOM);
        } else {
          Get.snackbar('Error', 'Failed to save image', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
        }
        return;
      }

      // Try saving non-image files via MediaStore on Android
      final mimeType = response.headers['content-type'] ?? 'application/octet-stream';
      final mediaStorePath = await MediaStoreSaver.saveFile(response.bodyBytes, filename, mimeType: mimeType);
      if (mediaStorePath != null) {
        Get.snackbar('Download complete', 'Saved to $mediaStorePath', snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final filePath = await _saveBytesToFile(response.bodyBytes, filename);
      if (filePath != null) {
        Get.snackbar('Download complete', 'Saved to $filePath', snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('Download Error', 'Unable to save file', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      print('Error downloading file: $e');
      Get.snackbar('Download Error', 'Unable to download file. Please try again.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<String?> _saveBytesToFile(Uint8List bytes, String filename) async {
    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          targetDir = downloadsDir;
        } else {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      targetDir ??= await getApplicationDocumentsDirectory();
      final filePath = path.join(targetDir.path, filename);
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      print('File save error: $e');
      return null;
    }
  }

  String _resolveFilename(Uri uri, {bool isImage = false}) {
    final raw = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'file_${DateTime.now().millisecondsSinceEpoch}';
    if (!isImage) return raw;
    final lower = raw.toLowerCase();
    final hasExt = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.bmp') || lower.endsWith('.heic');
    return hasExt ? raw : '$raw.jpg';
  }

  Future<void> getTrainings(bool isUpcoming) async {
    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      var tranings = <Training>[];
      final response = await repository.getTraining(
          isUpcoming ? upcomingPage : pastPage, isUpcoming ? 1 : 0);
      EasyLoading.dismiss(animation: true);
      tranings = response.data;

      if (isUpcoming) {
        if (upcomingPage == 1) {
          upcomingTrainingList.value = tranings;
        } else {
          upcomingTrainingList.addAll(tranings);
        }

        if (tranings.isNotEmpty) {
          upcomingPage++;
        }
      } else {
        if (pastPage == 1) {
          pastTrainingList.value = tranings;
        } else {
          pastTrainingList.addAll(tranings);
        }

        if (tranings.isNotEmpty) {
          pastPage++;
        }
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
    }
  }

  @override
  void onReady() {
    super.onReady();
  }
}
