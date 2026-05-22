import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/leaveissue/IssueLeaveResponse.dart';
import 'package:cnattendance/data/source/network/model/tadadetail/tadadetailresponse.dart';
import 'package:cnattendance/model/attachment.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:cnattendance/utils/media_store_saver.dart';

class EditTadaController extends GetxController {
  var fileList = <PlatformFile>[].obs;
  var attachmentList = <Attachment>[].obs;

  String id = "";

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final expensesController = TextEditingController();

  final key = GlobalKey<FormState>();

  void onFileClicked() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    final platformFile = result?.files.single;
    if (platformFile != null) {
      fileList.add(platformFile);
    }

  }

  void checkForm() {
    if (key.currentState!.validate()) {
      editTada();
    }
  }

  Future<String> getTadaDetail() async {
    Preferences preferences = Preferences();
    var uri =
    Uri.parse(await preferences.getAppUrl()+Constant.TADA_DETAIL_URL + "/${Get.arguments["tadaId"]}");

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(status: translate('loader.loading'),maskType: EasyLoadingMaskType.black);
      final response = await http.get(
        uri,
        headers: headers,
      );
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);
      EasyLoading.dismiss(animation: true);

      if (response.statusCode == 200) {
        final tadaResponse = TadaDetailResponse.fromJson(responseData);

        final data = tadaResponse.data;
        final attachments = <Attachment>[];
        for (var attachment in data.attachments.image) {
          attachments
              .add(Attachment(attachment.id, attachment.url, "image"));
        }
        for (var attachment in data.attachments.file) {
          attachments.add(Attachment(attachment.id, attachment.url, "file"));
        }

        titleController.text = parse(data.title).body!.text;
        descriptionController.text = parse(data.description).body!.text;
        expensesController.text = data.total_expense;
        attachmentList.value = attachments;

        return "Loaded";
      } else {
        var errorMessage = responseData['message'];
        print(errorMessage);
        throw errorMessage;
      }
    } catch (e) {
      print(e);
      showToast(e.toString());
      throw e;
    }
  }

  Future<String> editTada() async {
    try{
      Preferences preferences = Preferences();
      var uri = Uri.parse(await preferences.getAppUrl()+Constant.TADA_UPDATE_URL);

      String token = await preferences.getToken();

      Map<String, String> headers = {
        'Accept': 'application/json; charset=UTF-8',
        'Content-type': 'multipart/form-data',
        'Authorization': 'Bearer $token'
      };
      var requests = http.MultipartRequest('POST', uri);
      requests.headers.addAll(headers);


      requests.fields.addAll({
        "title": titleController.text,
        "description": descriptionController.text,
        "total_expense": expensesController.text,
        "tada_id": id,
      });

      for (var filed in fileList) {
        final file = File(filed.path!);
        final stream = http.ByteStream(Stream.castFrom(file.openRead()));
        final length = await file.length();

        final multipartFile = http.MultipartFile(
            'attachments[]',
            stream,
            length,
            filename: filed.name
        );
        requests.files.add(multipartFile);
      }

      EasyLoading.show(status: translate('loader.loading'),maskType: EasyLoadingMaskType.black);
      final responseStream = await requests.send();

      final response = await http.Response.fromStream(responseStream);

      EasyLoading.dismiss(animation: true);
      debugPrint(response.toString());
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        IssueLeaveResponse.fromJson(responseData);
        showToast("Tada has been updated");
        Get.back(result: true); // Pass result to trigger refresh
        return "Loaded";
      } else {
        var errorMessage = responseData['message'];
        print(errorMessage);
        throw errorMessage;
      }
    }catch(e){
      EasyLoading.dismiss(animation: true);
      showToast(e.toString());
      return "Failed";
    }
  }

  void removeItem(int index) {
    fileList.removeAt(index);
  }

  Future<void> removeAttachment(int id,int index) async {
    Preferences preferences = Preferences();
    var uri =
    Uri.parse(await preferences.getAppUrl()+Constant.TADA_DELETE_ATTACHMENT_URL + "/$id");

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(status: translate('loader.loading'),maskType: EasyLoadingMaskType.black);
      final response = await http.get(
        uri,
        headers: headers,
      );

      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        IssueLeaveResponse.fromJson(responseData);

        attachmentList.removeAt(index);

      } else {
        EasyLoading.dismiss(animation: true);
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
    getTadaDetail();
    id = Get.arguments['tadaId'];
    super.onInit();
  }

  Future<void> launchUrls(String _url) async {
    // Direct download instead of opening in browser
    await _downloadAndOpen(_url);
  }

  Future<void> launchFile(String _url) async {
    if (!await launchUrl(Uri.file(_url))) {
      throw Exception('Could not launch $_url');
    }
  }

  Future<void> _downloadAndOpen(String url) async {
    try {
      // Handle both relative and absolute URLs
      String fullUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // Relative URL - prepend base URL
        Preferences preferences = Preferences();
        String baseUrl = await preferences.getAppUrl();
        fullUrl = baseUrl + url;
      }
      
      final uri = Uri.parse(fullUrl);
      final filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'file_${DateTime.now().millisecondsSinceEpoch}';

      Preferences preferences = Preferences();
      String token = await preferences.getToken();
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
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
          showToast('Failed to save image');
        }
        return;
      }

      // Try saving generic files using MediaStore on Android first
      final mimeType = response.headers['content-type'] ?? 'application/octet-stream';
      final mediaStorePath = await MediaStoreSaver.saveFile(response.bodyBytes, filename, mimeType: mimeType);
      if (mediaStorePath != null) {
        showToast('Saved to gallery: $mediaStorePath');
        return;
      }

      final filePath = await _saveBytesToFile(response.bodyBytes, filename);
      if (filePath != null) {
        showToast('Saved to $filePath');
      } else {
        showToast('Download failed');
      }
    } catch (e) {
      print('Download error: $e');
      showToast('Download failed');
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
