import 'package:cnattendance/screen/projectscreen/taskdetailscreen/taskdetailcontroller.dart';
import 'package:flutter/material.dart';
import 'package:gallery_image_viewer/gallery_image_viewer.dart';
import 'package:get/get.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';

import '../../../../model/attachment.dart';

class ItemListBottom extends StatelessWidget {
  Future<String> _getFullUrl(String url) async {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final prefs = Preferences();
    final base = await prefs.getAppUrl();
    return base + url;
  }
  @override
  Widget build(BuildContext context) {
    final TaskDetailController model = Get.find();
    final attachments = <Attachment>[];

    for (var attachment in model.taskDetail.value.attachments) {
      if (attachment.type == "image") {
        attachments.add(attachment);
      }
    }
    return Container(
      padding: EdgeInsets.all(5),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 5.0,
        mainAxisSpacing: 5.0,
        children: List.generate(attachments.length, (index) {
          final attachment = attachments[index];
          return FutureBuilder<String>(
            future: _getFullUrl(attachment.url),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              final fullUrl = snapshot.data!;
              return GestureDetector(
                  onTap: () {
                    try {
                      final imageProvider = Image.network(fullUrl).image;
                      showImageViewer(context, imageProvider, swipeDismissible: true,
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
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: double.infinity,
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
                            model.launchUrls(fullUrl);
                          },
                          child: Card(
                            elevation: 0,
                            color: Colors.blueAccent,
                            shape: CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.download,
                                color: Colors.white,
                              ),
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
