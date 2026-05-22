import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/widget/notification/notificationcard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NotificationList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final NotificationController model = Get.find();
    return Obx(
      () => model.isInitialLoading.value
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading Notifications...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : model.notificationList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You have no notifications at this time',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ListView.builder(
                      primary: false,
                      controller: model.controller,
                      itemCount: model.notificationList.length,
                      itemBuilder: (ctx, index) {
                        return NotificationCard(
                            id: model.notificationList[index].id,
                            name: model.notificationList[index].title,
                            month: model.notificationList[index].month,
                            day: model.notificationList[index].day.toString(),
                            desc: model.notificationList[index].description,
                            date: model.notificationList[index].date.toString());
                      }),
                ),
    );
  }
}
