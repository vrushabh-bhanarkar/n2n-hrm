import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/provider/meetingcontroller.dart';
import 'package:cnattendance/screen/profile/employeedetailscreen.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class MeetingDetailScreen extends StatelessWidget {
  static const routeName = '/meetingdetailscreen';

  Future<void> _openExternalLink(String rawUrl) async {
    final normalized =
        rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
            ? rawUrl
            : 'https://$rawUrl';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildAgendaWithLinks(String agenda) {
    final urlRegex =
        RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+)', caseSensitive: false);
    final matches = urlRegex.allMatches(agenda).toList();
    if (matches.isEmpty) {
      return Text(
        agenda,
        style: TextStyle(color: Colors.white, fontSize: 14),
      );
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(
          text: agenda.substring(cursor, match.start),
          style: TextStyle(color: Colors.white, fontSize: 14),
        ));
      }

      final linkText = agenda.substring(match.start, match.end);
      spans.add(TextSpan(
        text: linkText,
        style: TextStyle(
          color: Colors.lightBlueAccent,
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            _openExternalLink(linkText);
          },
      ));
      cursor = match.end;
    }

    if (cursor < agenda.length) {
      spans.add(TextSpan(
        text: agenda.substring(cursor),
        style: TextStyle(color: Colors.white, fontSize: 14),
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final model = Get.put(MeetingController());
    final args = Get.arguments["id"] as int;
    final item = model.meetingList.where((item) => item.id == args).first;
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(translate('meeting_detail_screen.meeting_detail'),
              style: TextStyle(color: Colors.white)),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                item.image.isNotEmpty && item.image.startsWith('http')
                    ? Column(
                        children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: item.image,
                                height: 200,
                                fit: BoxFit.cover,
                                width: MediaQuery.of(context).size.width,
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: const Center(
                                      child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported,
                                      size: 50),
                                ),
                              )),
                          gaps(10),
                        ],
                      )
                    : SizedBox.shrink(),
                Text(
                  item.title,
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                SizedBox(
                  height: 15,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translate('meeting_list_screen.venue'),
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(item.venue,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      height: 30,
                      child: VerticalDivider(
                        width: 1,
                        color: Colors.white54,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Date",
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(item.meetingDate,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      height: 30,
                      child: VerticalDivider(
                        width: 1,
                        color: Colors.white54,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Time",
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(item.meetingStartTime,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                // if (item.createdBy.isNotEmpty)
                //   SizedBox(
                //     height: 15,
                //   ),
                // if (item.createdBy.isNotEmpty)
                //   Card(
                //     elevation: 0,
                //     color: Colors.white24,
                //     margin: EdgeInsets.zero,
                //     shape: ButtonBorder(),
                //     child: Padding(
                //       padding:
                //           EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                //       child: Row(
                //         children: [
                //           Text(
                //             'Host',
                //             style: TextStyle(
                //                 color: Colors.white,
                //                 fontSize: 16,
                //                 fontWeight: FontWeight.bold),
                //           ),
                //           Spacer(),
                //           Text(
                //             '${item.createdBy}',
                //             style: TextStyle(
                //                 color: Colors.white,
                //                 fontSize: 15,
                //                 fontWeight: FontWeight.normal),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ),
                SizedBox(
                  height: 15,
                ),
                Card(
                  elevation: 0,
                  color: Colors.white24,
                  margin: EdgeInsets.zero,
                  shape: ButtonBorder(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Description",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        _buildAgendaWithLinks(item.agenda)
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 15,
                ),
                Card(
                  elevation: 0,
                  color: Colors.white24,
                  margin: EdgeInsets.zero,
                  shape: ButtonBorder(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate('meeting_detail_screen.participants'),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        gaps(10),
                        ListView.separated(
                            primary: false,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  Get.to(EmployeeDetailScreen(), arguments: {
                                    "employeeId": item.participator[index].id
                                  });
                                },
                                child: ListTile(
                                  visualDensity: VisualDensity.compact,
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 0),
                                  minVerticalPadding: 0,
                                  minTileHeight: 35,
                                  title: Text(
                                    item.participator[index].name,
                                    style: TextStyle(fontSize: 15),
                                  ),
                                  trailing: Text(
                                    item.participator[index].post,
                                    style: TextStyle(fontSize: 15),
                                  ),
                                  minLeadingWidth: 1,
                                  leading: Text(
                                    "${index + 1}.",
                                    // Display index
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  textColor: Colors.white,
                                ),
                              );
                            },
                            separatorBuilder: (context, index) {
                              return Divider(
                                height: 1,
                                indent: 2,
                                endIndent: 2,
                                color: Colors.white12,
                              );
                            },
                            itemCount: item.participator.length)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget gaps(int value) {
    return const SizedBox(
      height: 10,
    );
  }
}
