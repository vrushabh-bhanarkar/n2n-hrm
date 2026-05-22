import 'package:cnattendance/model/employeeattendancereport.dart';
import 'package:cnattendance/provider/attendancereportprovider.dart';
import 'package:cnattendance/utils/fallback_localization.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/widget/attendancescreen/attendancecardview.dart';

class ReportListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final attendanceList =
        Provider.of<AttendanceReportProvider>(context).attendanceReport;
    final currentMonth =
        Provider.of<AttendanceReportProvider>(context).currentMonthReport;

    final attendanceGrouped =
        EmployeeAttendanceReport.groupAttendanceByDate(attendanceList);
    final groupedEntries = attendanceGrouped.keys.toList();

    if (attendanceList.length > 0) {
      return SingleChildScrollView(
        child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                attendanceSummary(currentMonth),
                SizedBox(
                  height: 10,
                ),
                attendanceReportTitle(),
                ListView.builder(
                    shrinkWrap: true,
                    primary: false,
                    itemCount: groupedEntries.length,
                    itemBuilder: (ctx, i) {
                      return AttendanceCardView(i, groupedEntries[i],
                          attendanceGrouped[groupedEntries[i]] ?? []);
                    }),
              ],
            )),
      );
    } else {
      final isLoading =
          Provider.of<AttendanceReportProvider>(context).isLoading;

      if (isLoading) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      } else {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No attendance records found',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        );
      }
    }
  }

  Widget attendanceSummary(Map<String, dynamic> currentMonth) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
            child: Container(
              color: Colors.white12,
              padding: EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    safeTranslate('attendance_screen.present_days'),
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currentMonth["present_days"],
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 10,
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
            child: Container(
              color: Colors.white12,
              padding: EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    safeTranslate('attendance_screen.worked_hours'),
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Text(
                    currentMonth["worked_hour"],
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget attendanceReportTitle() {
    return Card(
      elevation: 0,
      color: Colors.black38,
      shape: ButtonBorder(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Container(
                child: Text(safeTranslate('attendance_screen.date'),
                    style: TextStyle(fontSize: 14, color: Colors.white),
                    textAlign: TextAlign.start),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                child: Text(safeTranslate('attendance_screen.day'),
                    style: TextStyle(fontSize: 14, color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                child: Text(safeTranslate('attendance_screen.start_time'),
                    style: TextStyle(fontSize: 14, color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                child: Text(safeTranslate('attendance_screen.end_time'),
                    style: TextStyle(fontSize: 14, color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                child: Text("Action",
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 14, color: Colors.white),
                    textAlign: TextAlign.right),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
