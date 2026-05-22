import 'package:cnattendance/model/attachment.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/services.dart';
import 'package:cnattendance/utils/media_store_saver.dart';

class FilesListBottom extends StatelessWidget {
  final List<Attachment> attachments;

  FilesListBottom(this.attachments);
  @override
  Widget build(BuildContext context) {
    final attachList = <Attachment>[];
    for(var attach in attachments){
      if(attach.type == "file"){
        attachList.add(attach);
      }
    }
    return Container(
        padding: EdgeInsets.all(5),
        child: ListView.builder(
          itemCount: attachList.length,
          primary: false,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            Attachment item = attachList[index];
            final filename = item.url.split('/').last;
            return Card(
                elevation: 0,
                color: Colors.white12,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          filename,
                          style: TextStyle(color: Colors.white, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          try {
                            await _downloadAndSave(item.url, context);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Unable to download attachment')),
                            );
                          }
                        },
                        child: Icon(
                          Icons.download,
                          color: Colors.white,
                        ),
                      )
                    ],
                  ),
                ));
          },
        ));
  }
}

Future<void> _downloadAndSave(String url, BuildContext context) async {
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
      throw Exception('Failed to download');
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

      final filePath = await _saveBytesToFile(bytes, filename);
      if (filePath != null) {
        showToast('Saved to $filePath');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save image')));
      }
      return;
    }

    // Try saving non-image files via MediaStore on Android
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed')));
    }
  } catch (e) {
    print('Download error: $e');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed')));
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
