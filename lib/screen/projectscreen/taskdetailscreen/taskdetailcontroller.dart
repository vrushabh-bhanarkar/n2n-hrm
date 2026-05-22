import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/checkliststatustoggle/CheckListStatusToggleResponse.dart';
import 'package:cnattendance/data/source/network/model/taskdetail/taskdetail.dart';
import 'package:cnattendance/model/checklist.dart';
import 'package:cnattendance/model/member.dart';
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

import '../../../model/attachment.dart';

class TaskDetailController extends GetxController {
  var taskDetail =
      (Task.all(0, "", "", "", "", "", "", "Completed", 0, 0, true, [], [], [],
          isTimerRunning: false, totalTimeSpentSeconds: 0))
          .obs;

  var memberImages = [].obs;
  var leaderImages = [].obs;
  var isTimerRunning = false.obs;
  var totalTimeSpentSeconds = 0.obs;
  var _timerStopwatch = Stopwatch();
  var _localElapsedSeconds = 0.obs;

  Future<TaskDetailResponse> getTaskOverview() async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() +
        Constant.TASK_DETAIL_URL +
        "/" +
        Get.arguments["id"].toString());

    String token = await preferences.getToken();
    bool isAd = await preferences.getEnglishDate();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await http.get(
        uri,
        headers: headers,
      );
      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final taskResponse = TaskDetailResponse.fromJson(responseData);

        List<Member> members = [];
        memberImages.clear();
        for (var member in taskResponse.data.assigned_member) {
          members.add(
              Member(member.id, member.name, member.avatar, post: member.post));
          memberImages.add(member.avatar);
        }

        List<Checklist> checkLists = [];
        for (var checkList in taskResponse.data.checklists) {
          checkLists.add(Checklist(checkList.id, checkList.task_id,
              checkList.name, checkList.is_completed));
        }

        List<Attachment> attachments = [];
        for (var attachment in taskResponse.data.attachments) {
          if (attachment.type == "image") {
            attachments.add(Attachment(0, attachment.attachment_url, "image"));
          } else {
            attachments.add(Attachment(0, attachment.attachment_url, "file"));
          }
        }

        DateTime startDate =
            DateFormat("MMM dd yyyy").parse(taskResponse.data.start_date);

        NepaliDateTime nepaliStartDate = startDate.toNepaliDateTime();

        String nepaliStartTempDate =
            NepaliDateFormat("MMM dd yyyy").format(nepaliStartDate);

        var task = Task.all(
            taskResponse.data.task_id,
            taskResponse.data.task_name,
            taskResponse.data.project_name,
            taskResponse.data.description,
            isAd ? taskResponse.data.start_date : nepaliStartTempDate,
            taskResponse.data.deadline,
            taskResponse.data.priority,
            taskResponse.data.status,
            taskResponse.data.task_progress_percent,
            taskResponse.data.task_comments.length,
            taskResponse.data.has_checklist,
            members,
            checkLists,
            attachments,
            isTimerRunning: taskResponse.data.is_timer_running,
            totalTimeSpentSeconds: taskResponse.data.total_time_spent_seconds);

        taskDetail.value = task;
        isTimerRunning.value = task.isTimerRunning;
        totalTimeSpentSeconds.value = task.totalTimeSpentSeconds;
        _localElapsedSeconds.value = task.totalTimeSpentSeconds;

        if (isTimerRunning.value) {
          _timerStopwatch.reset();
          _timerStopwatch.start();
          _startLocalTimer();
        } else {
          _timerStopwatch.stop();
          _timerStopwatch.reset();
        }

        return taskResponse;
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

  Future<bool> checkListToggle(String checkListId) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() +
        Constant.UPDATE_CHECKLIST_TOGGLE_URL +
        "/" +
        checkListId);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    debugPrint(uri.toString());
    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await http.get(
        uri,
        headers: headers,
      );
      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final taskResponse =
            CheckListStatusToggleResponse.fromJson(responseData);

        return true;
      } else {
        var errorMessage = responseData['message'];
        print(errorMessage);
        return false;
      }
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> checkListTaskToggle(String taskId) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() +
        Constant.UPDATE_TASK_TOGGLE_URL +
        "/" +
        taskId);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    debugPrint(uri.toString());
    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await http.get(
        uri,
        headers: headers,
      );
      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        Get.back();
        showToast("Task completed");
        // Reload task details to reflect the status change
        await getTaskOverview();
        return true;
      } else {
        var errorMessage = responseData['message'];
        print(errorMessage);
        return false;
      }
    } catch (e) {
      print(e);
      return false;
    }
  }

  /// Change task status via API toggle endpoint
  Future<bool> changeStatus() async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() +
        Constant.UPDATE_TASK_TOGGLE_URL +
        "/" +
        Get.arguments["id"].toString());

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await http.get(uri, headers: headers);
      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
        final data = responseData['data'];
        final newStatus = data['status'] ?? taskDetail.value.status;
        showToast(responseData['message'] ?? 'Status changed to $newStatus');
        await getTaskOverview();
        return true;
      } else {
        showToast(responseData['message'] ?? 'Failed to change status');
        return false;
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      print(e);
      showToast('Error changing status');
      return false;
    }
  }

  Future<void> launchUrls(String _url) async {
    // Perform direct download and open to avoid redirecting to external browsers
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

      // If image, save to gallery
      final lower = filename.toLowerCase();
      final isImage = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.bmp') || lower.endsWith('.heic');

      if (isImage) {
        final Uint8List bytes = response.bodyBytes;
        final mediaStorePath = await MediaStoreSaver.saveImage(bytes, filename);
        if (mediaStorePath != null) {
          showToast('Saved to gallery: $mediaStorePath');
          return;
        }

        // If MediaStore failed, write to Downloads as fallback
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

  @override
  void onInit() {
    getTaskOverview();
    super.onInit();
  }

  @override
  void onClose() {
    _timerStopwatch.stop();
    super.onClose();
  }

  void _startLocalTimer() {
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 1));
      if (!isTimerRunning.value) return false;
      _localElapsedSeconds.value = totalTimeSpentSeconds.value +
          _timerStopwatch.elapsed.inSeconds;
      return true;
    });
  }

  int get displaySeconds => _localElapsedSeconds.value;

  String get formattedTime {
    final total = _localElapsedSeconds.value;
    final h = (total ~/ 3600).toString().padLeft(2, '0');
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<bool> startTimer() async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() +
        Constant.START_TASK_TIMER_URL +
        "/" +
        Get.arguments["id"].toString() +
        "/start-timer");

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await http.post(uri, headers: headers, body: '{}');
      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
        final data = responseData['data'];
        isTimerRunning.value = true;
        totalTimeSpentSeconds.value = data['total_time_spent_seconds'] ?? 0;
        _localElapsedSeconds.value = totalTimeSpentSeconds.value;
        _timerStopwatch.reset();
        _timerStopwatch.start();
        _startLocalTimer();
        taskDetail.value.isTimerRunning = true;
        taskDetail.value.totalTimeSpentSeconds = totalTimeSpentSeconds.value;
        showToast(responseData['message'] ?? 'Timer started');
        return true;
      } else {
        showToast(responseData['message'] ?? 'Failed to start timer');
        return false;
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      print(e);
      showToast('Error starting timer');
      return false;
    }
  }

  Future<bool> stopTimer() async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() +
        Constant.STOP_TASK_TIMER_URL +
        "/" +
        Get.arguments["id"].toString() +
        "/stop-timer");

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await http.post(uri, headers: headers, body: '{}');
      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
        final data = responseData['data'];
        _timerStopwatch.stop();
        _timerStopwatch.reset();
        isTimerRunning.value = false;
        totalTimeSpentSeconds.value = data['total_time_spent_seconds'] ?? 0;
        _localElapsedSeconds.value = totalTimeSpentSeconds.value;
        taskDetail.value.isTimerRunning = false;
        taskDetail.value.totalTimeSpentSeconds = totalTimeSpentSeconds.value;
        showToast(responseData['message'] ?? 'Timer stopped');
        return true;
      } else {
        showToast(responseData['message'] ?? 'Failed to stop timer');
        return false;
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      print(e);
      showToast('Error stopping timer');
      return false;
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
