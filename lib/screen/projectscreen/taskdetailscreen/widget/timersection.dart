import 'package:cnattendance/screen/projectscreen/taskdetailscreen/taskdetailcontroller.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';

class TimerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final TaskDetailController controller = Get.find();
    return Card(
      elevation: 0,
      color: Colors.white24,
      margin: EdgeInsets.zero,
      shape: ButtonBorder(),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Time Tracker",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Center(
              child: Obx(
                () => Text(
                  controller.formattedTime,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            Center(
              child: Obx(
                () => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: controller.isTimerRunning.value
                        ? HexColor("#e74c3c")
                        : HexColor("#036eb7"),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    if (controller.isTimerRunning.value) {
                      controller.stopTimer();
                    } else {
                      controller.startTimer();
                    }
                  },
                  icon: Icon(
                    controller.isTimerRunning.value
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                    color: Colors.white,
                  ),
                  label: Text(
                    controller.isTimerRunning.value
                        ? "Stop Timer"
                        : "Start Timer",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
