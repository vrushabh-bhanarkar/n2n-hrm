import 'package:cnattendance/model/attachment.dart';
import 'package:cnattendance/model/checklist.dart';
import 'package:cnattendance/model/member.dart';

class Task {
  int? id;
  String? name;
  String? projectName;
  String? description;
  String? date;
  String? endDate;
  String? priority;
  String status;
  int? progress;
  int? noOfComments;
  bool? has_checklist;
  bool? hasProgress = false;
  bool isTimerRunning;
  int totalTimeSpentSeconds;
  List<Member> members = [];
  List<Checklist> checkList = [];
  List<Attachment> attachments = [];

  Task.all(
      this.id,
      this.name,
      this.projectName,
      this.description,
      this.date,
      this.endDate,
      this.priority,
      this.status,
      this.progress,
      this.noOfComments,
      this.has_checklist,
      this.members,
      this.checkList,
      this.attachments,
      {this.isTimerRunning = false,
      this.totalTimeSpentSeconds = 0});

  Task(this.id, this.name, this.projectName, this.date, this.endDate,
      this.status,{this.progress = 0,this.members = const [],this.priority = "",this.hasProgress = false,this.isTimerRunning = false,this.totalTimeSpentSeconds = 0});
}
