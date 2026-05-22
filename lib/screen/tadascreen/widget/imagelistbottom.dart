import 'package:cnattendance/model/attachment.dart';
import 'package:flutter/material.dart';
import 'package:gallery_image_viewer/gallery_image_viewer.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
// removed image_gallery_saver; using platform MediaStore saver instead
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/services.dart';
import 'package:cnattendance/utils/media_store_saver.dart';

class ItemListBottom extends StatelessWidget{
  final List<Attachment> attachments;

  ItemListBottom(this.attachments);

  Future<String> _getFullUrl(String url) async {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // Relative URL - prepend base URL
    Preferences preferences = Preferences();
    String baseUrl = await preferences.getAppUrl();
    return baseUrl + url;
  }

  @override
  Widget build(BuildContext context) {
    final attachList = <Attachment>[];
    for(var attach in attachments){
      if(attach.type == "image"){
        attachList.add(attach);
      }
    }
    return Container(
      padding: EdgeInsets.all(5),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 5.0,
        mainAxisSpacing: 5.0,
        children: List.generate(attachList.length, (index) {
          Attachment item = attachList[index];
          return FutureBuilder<String>(
            future: _getFullUrl(item.url),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              final fullUrl = snapshot.data!;
              return GestureDetector(
                  onTap: () {
                    try {
                      final imageProvider = Image.network(fullUrl).image;
                      showImageViewer(context, imageProvider,
                          swipeDismissible: true,
                          onViewerDismissed: () {
                            print("dismissed");
                          });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unable to load image')),
                      );
                    }
                  },
                  child: Stack(children: [
                    Image.network(
                      fullUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          color: Colors.grey[300],
                          child: Center(
                            child: Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                    Positioned(
                        bottom: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              await _downloadAndSave(fullUrl, context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Unable to download attachment')),
                              );
                            }
                          },
                          child: Card(
                            elevation: 0,
                            color: Colors.black,
                            shape: CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(Icons.download,color: Colors.white,),
                            ),
                          ),
                        ))
                  ]));
            },
          );
        }),
      ),
    );
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

    final Uint8List bytes = response.bodyBytes;
    final mediaStorePath = await MediaStoreSaver.saveImage(bytes, filename);
    if (mediaStorePath != null) {
      showToast('Saved to gallery: $mediaStorePath');
      return;
    }

    // Try saving as generic file via MediaStore as a fallback
    final mimeType = response.headers['content-type'] ?? 'image/jpeg';
    final mediaFilePath = await MediaStoreSaver.saveFile(bytes, filename, mimeType: mimeType);
    if (mediaFilePath != null) {
      showToast('Saved to gallery: $mediaFilePath');
      return;
    }

    // Fallback: write to Downloads/internal storage
    final filePath = await _saveBytesToFile(bytes, filename);
    if (filePath != null) {
      showToast('Saved to $filePath');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save image')));
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

// image_gallery_saver helpers removed