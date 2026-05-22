import 'package:cnattendance/screens/chat/project_chat_screen.dart';
import 'package:cnattendance/screen/projectscreen/projectdetailscreen/projectdetailcontroller.dart';
import 'package:cnattendance/screen/projectscreen/projectdetailscreen/widget/attachmentsection.dart';
import 'package:cnattendance/screen/projectscreen/projectdetailscreen/widget/descriptionsection.dart';
import 'package:cnattendance/screen/projectscreen/projectdetailscreen/widget/headersection.dart';
import 'package:cnattendance/screen/projectscreen/projectdetailscreen/widget/tasksection.dart';
import 'package:cnattendance/screen/projectscreen/projectdetailscreen/widget/teamsection.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProjectDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(ProjectDetailController());
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            actions: [
             IconButton(onPressed: () {
               Get.to(() => ProjectChatScreen(
                 projectId: model.project.value.id,
                 projectName: model.project.value.name,
                 leaders: model.project.value.leaders,
                 members: model.project.value.members,
               ));
             }, icon: Icon(Icons.messenger_outline,color: Colors.white,))
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () {
                return model.getProjectOverview();
              },
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Obx(
                  () => Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 20),
                    child: model.project.value.id == 0
                        ? SizedBox()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HeaderSection(),
                              SizedBox(
                                height: 20,
                              ),
                              DescriptionSection(),
                              SizedBox(
                                height: 20,
                              ),
                              TeamSection(),
                              SizedBox(
                                height: 20,
                              ),
                              AttachmentSection(),
                              SizedBox(
                                height: 10,
                              ),
                              Obx(() => model.project.value.tasks.length != 0
                                  ? TaskSection()
                                  : SizedBox())
                            ],
                          ),
                  ),
                ),
              ),
            ),
          )),
    );
  }
}
