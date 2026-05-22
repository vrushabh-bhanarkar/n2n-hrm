import 'package:cnattendance/provider/holidaycontroller.dart';
import 'package:cnattendance/widget/holiday/holidaycard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HolidayCardView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final HolidayController model = Get.find();
    return Obx(
      () {
        // Check if the list is empty and show empty state
        if (model.holidayList.isEmpty) {
          return Container(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.white54),
                  SizedBox(height: 16),
                  Text('No holidays found',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => model.getHolidays(),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ListView.builder(
              shrinkWrap: true,
              primary: false,
              itemCount: model.holidayList.length,
              itemBuilder: (ctx, i) {
                return Holidaycard(
                  id: model.holidayList[i].id,
                  name: model.holidayList[i].title,
                  month: model.holidayList[i].month,
                  day: model.holidayList[i].day,
                  desc: model.holidayList[i].description,
                  isPublicHoliday: model.holidayList[i].isPublicHoliday,
                );
              }),
        );
      },
    );
  }
}
