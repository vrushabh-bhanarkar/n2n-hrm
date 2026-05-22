import 'package:cnattendance/screen/projectscreen/taskdetailscreen/widget/fileslistbottom.dart';
import 'package:cnattendance/screen/projectscreen/taskdetailscreen/widget/imagelistbottom.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

class AttachmentBottomSheet extends StatefulWidget {
  @override
  State<AttachmentBottomSheet> createState() => _AttachmentBottomSheetState();
}

class _AttachmentBottomSheetState extends State<AttachmentBottomSheet> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .9,
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: RadialDecoration(),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    translate('task_detail_screen.attachments'),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                      onTap: () {
                        Get.back();
                      },
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                      )),
                ],
              ),
            ),
            SizedBox(
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      0,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        translate('project_detail_screen.image'),
                        style: TextStyle(
                          color: _currentPage == 0 ? Colors.white : Colors.white70,
                          fontSize: 15,
                          fontWeight: _currentPage == 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (_currentPage == 0)
                        Container(
                          margin: EdgeInsets.only(top: 5),
                          height: 2,
                          width: 50,
                          color: Colors.white,
                        )
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      1,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        translate('project_detail_screen.files'),
                        style: TextStyle(
                          color: _currentPage == 1 ? Colors.white : Colors.white70,
                          fontSize: 15,
                          fontWeight: _currentPage == 1 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (_currentPage == 1)
                        Container(
                          margin: EdgeInsets.only(top: 5),
                          height: 2,
                          width: 50,
                          color: Colors.white,
                        )
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 10,
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  ItemListBottom(),
                  FilesListBottom(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
