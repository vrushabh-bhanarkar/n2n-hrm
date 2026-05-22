import 'package:cnattendance/data/source/network/model/teamsheet/Employee.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/screen/profile/employeedetailscreen.dart';
import 'package:cnattendance/screen/profile/teamsheetscreen.dart';
import 'package:cnattendance/widget/safe_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:cnattendance/utils/fallback_localization.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class MyTeam extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final employee =
        Provider.of<DashboardProvider>(context, listen: true).employeeList;
    return Visibility(
      visible: employee.isNotEmpty,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  safeTranslate('home_screen.my_team'),
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    Get.to(TeamSheetScreen(), arguments: {
                      "department":
                          context.read<DashboardProvider>().department,
                      "branch": context.read<DashboardProvider>().branch
                    });
                  },
                  child: Text(
                    safeTranslate('home_screen.view_all'),
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
              height: 100,
              child: ListView.builder(
                physics: PageScrollPhysics(),
                primary: false,
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                itemCount: employee.length,
                itemBuilder: (context, index) {
                  return teamCard(employee[index]);
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

Widget teamCard(Employee teamList) {
  return InkWell(
    onTap: () {
      Get.to(EmployeeDetailScreen(),
          arguments: {"employeeId": teamList.id.toString()});
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              margin: EdgeInsets.zero,
              shape: CircleBorder(),
              elevation: 0,
              color: teamList.onlineStatus == "1"
                  ? Colors.green
                  : Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(3.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    color: Colors.white,
                    child: SafeCachedImage(
                      imageUrl: teamList.avatar,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      borderRadius: 0,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 8,
            ),
            Text(
              teamList.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            )
          ],
        ),
      ),
    ),
  );
}
