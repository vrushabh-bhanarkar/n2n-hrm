import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/projectdetail/ProjectDetailResponse.dart';
import 'package:cnattendance/model/attachment.dart';
import 'package:cnattendance/model/member.dart';
import 'package:cnattendance/model/project.dart';
import 'package:cnattendance/model/task.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:cnattendance/utils/media_store_saver.dart';

class ProjectDetailController extends GetxController {
  var project = Project(0, "", "","", "", "", "", 0, 0, [], [], []).obs;

  var memberImages = [].obs;
  var leaderImages = [].obs;

  Future<String> getProjectOverview() async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(
        await preferences.getAppUrl() +Constant.PROJECT_DETAIL_URL + "/" + Get.arguments["id"].toString());

    String token = await preferences.getToken();
    bool isAd = await preferences.getEnglishDate();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(status: translate('loader.loading'), maskType: EasyLoadingMaskType.black);
      final response = await http.get(
        uri,
        headers: headers,
      );

      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final projectResponse = ProjectDetailResponse.fromJson(responseData);

        List<Member> members = [];
        memberImages.clear();
        for (var member in projectResponse.data.assigned_member) {
          members.add(
              Member(member.id, member.name, member.avatar, post: member.post));
          memberImages.add(member.avatar);
        }

        List<Member> leaders = [];
        leaderImages.clear();
        for (var member in projectResponse.data.project_leader) {
          leaders.add(
              Member(member.id, member.name, member.avatar, post: member.post));
          leaderImages.add(member.avatar);
        }

        List<Attachment> attachments = [];
        for (var attachment in projectResponse.data.attachments) {
          if (attachment.type == "image") {
            attachments.add(Attachment(0, attachment.attachment_url, "image"));
          } else {
            attachments.add(Attachment(0, attachment.attachment_url, "file"));
          }
        }

        DateTime tempDate =
            DateFormat("yyyy-mm-dd").parse(projectResponse.data.start_date);
        NepaliDateTime nepaliDate = tempDate.toNepaliDateTime();

        String nepaliTempDate =
            NepaliDateFormat("MMMM dd yyyy").format(nepaliDate);

        Project response = Project(
            projectResponse.data.id,
            projectResponse.data.name,
            projectResponse.data.slug,
            projectResponse.data.description,
            isAd ? projectResponse.data.start_date : nepaliTempDate,
            projectResponse.data.priority,
            projectResponse.data.status,
            projectResponse.data.progress_percent,
            projectResponse.data.assigned_task_count,
            members,
            leaders,
            attachments);

        final List<Task> taskList = [];
        print(projectResponse.data.assigned_task_detail.length);
        for (var task in projectResponse.data.assigned_task_detail) {
          taskList.add(Task(
              task.task_id,
              task.task_name,
              projectResponse.data.name,
              task.start_date,
              task.deadline,
              task.status));
        }

        response.tasks.addAll(taskList);
        project.value = response;
        return "Loaded";
      } else {
        var errorMessage = responseData['message'];
        print(errorMessage);
        throw errorMessage;
      }
    } catch (e) {
      print(e);
      throw e;
    }
  }

  @override
  void onInit() {
    getProjectOverview();
    super.onInit();
  }

  Future<void> launchUrls(String _url) async {
    // Perform direct download to avoid redirecting to external browsers
    await _downloadAndOpen(_url);
  }

  Future<void> _downloadAndOpen(String url) async {
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

      Preferences _prefs = Preferences();
      String _token = await _prefs.getToken();
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json'
      });
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      final lower = filename.toLowerCase();
      final isImage = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.bmp') || lower.endsWith('.heic');

      if (isImage) {
        final Uint8List bytes = response.bodyBytes;
        final mediaStorePath = await MediaStoreSaver.saveImage(bytes, filename);
        if (mediaStorePath != null) {
          showToast('Saved to gallery: $mediaStorePath');
          return;
        }

        final fallbackPath = await _saveBytesToFile(bytes, filename);
        if (fallbackPath != null) {
          showToast('Saved to $fallbackPath');
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

  bool _isGallerySaveSuccess(dynamic result) {
    if (result == null) return false;
    try {
      if (result is Map) {
        return result['isSuccess'] == true || result['filePath'] != null || result['savedFilePath'] != null;
      }
    } catch (_) {}
    return false;
  }

  String? _extractSavedPath(dynamic result) {
    if (result is Map) {
      final path = result['filePath'] ?? result['savedFilePath'] ?? result['path'];
      if (path != null) return path.toString();
    }
    return null;
  }
}
