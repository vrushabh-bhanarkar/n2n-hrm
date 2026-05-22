import 'package:cnattendance/data/source/network/model/attendancereport/AttendanceSummary.dart';
import 'package:cnattendance/data/source/network/model/attendancereport/EmployeeAttendance.dart';
import 'package:cnattendance/data/source/network/model/attendancereport/EmployeeTodayAttendance.dart';
import 'package:cnattendance/model/employeeattendancereport.dart';
import 'package:cnattendance/model/month.dart';
import 'package:cnattendance/repositories/attendancereportrepository.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';

class AttendanceReportProvider with ChangeNotifier {
  final List<EmployeeAttendanceReport> _attendanceReport = [];
  AttendanceReportRepository repository = AttendanceReportRepository();

  final Map<String, dynamic> _todayReport = {
    'check_in_at': '-',
    'check_out_at': '-',
    'production_hour': '0 hr 0 min',
    'production_percent': 0.0,
  };

  final Map<String, dynamic> _currentMonthReport = {
    'present_days': '0',
    'worked_hour': '0h 0m',
  };

  List<Month> month = [];

  var isLoading = false;

  int selectedMonth = DateTime.now().month - 1;

  List<EmployeeAttendanceReport> get attendanceReport {
    return [..._attendanceReport];
  }

  Map<String, dynamic> get todayReport {
    return _todayReport;
  }

  Map<String, dynamic> get currentMonthReport {
    return _currentMonthReport;
  }

  void getDate() async {
    final isAd = (await repository.getDateInAd());
    month = isAd ? engMonth : nepaliMonth;

    NepaliDateTime currentTime = NepaliDateTime.now();
    selectedMonth =
        await isAd ? DateTime.now().month - 1 : currentTime.month - 1;
    // Don't call notifyListeners here - let getAttendanceReport handle it
    await getAttendanceReport();
  }

  Future<void> getAttendanceReport() async {
    isLoading = true;
    // Use Future.microtask to defer notifyListeners until after build
    Future.microtask(() => notifyListeners());
    try {
      final responseJson = await repository.getAttendanceReport(selectedMonth);
      isLoading = false;
      makeTodayReport(responseJson.data.employeeTodayAttendance);
      makeMonthlyReport(responseJson.data.attendanceSummary);
      makeAttendanceReport(responseJson.data.employeeAttendance);
      getProdHour(
          int.parse(responseJson.data.employeeTodayAttendance.productiveTime));
      // Final notification after all data is loaded
      Future.microtask(() => notifyListeners());
    } catch (error) {
      isLoading = false;
      Future.microtask(() => notifyListeners());
      print('Error loading attendance report: $error');
      rethrow;
    }
  }

  void makeAttendanceReport(List<EmployeeAttendance> employeeAttendance) {
    _attendanceReport.clear();
    for (var item in employeeAttendance) {
      _attendanceReport.add(EmployeeAttendanceReport(
        id: item.id,
        attendance_date: item.attendanceDate,
        week_day: item.weekDay,
        worked_hours: item.workedhrs ?? "-",
        working_hours: item.workingHour,
        check_in: item.checkIn,
        check_out: item.checkOut,
        overTime: item.overTime,
        underTime: item.underTime,
        isOverTime: item.isOverTime,
        isUnderTime: item.isUnderTime,
        worked_hours_min: item.workedhrsMin,
        working_hours_min: item.workingHourMin,
      ));
    }
    // Don't notify here - let the parent method handle it
  }

  void makeTodayReport(EmployeeTodayAttendance employeeTodayAttendance) {
    _todayReport['check_in_at'] = employeeTodayAttendance.checkInAt;
    _todayReport['check_out_at'] = employeeTodayAttendance.checkOutAt;

    print(_todayReport['check_in_at']);
    print(_todayReport['check_out_at']);
    // Don't notify here - let the parent method handle it
  }

  void makeMonthlyReport(AttendanceSummary attendanceSummary) {
    _currentMonthReport['present_days'] = attendanceSummary.totalPresent;

    // attendanceSummary.totalWorkedHours may be returned as minutes (numeric) or already formatted string.
    // Try to parse as integer minutes; if successful, format to `Xh Ym`, otherwise use as-is.
    final raw = attendanceSummary.totalWorkedHours.toString();
    final parsed = int.tryParse(raw);
    if (parsed != null) {
      final hours = parsed ~/ 60;
      final mins = parsed % 60;
      _currentMonthReport['worked_hour'] = "${hours}h ${mins}m";
    } else {
      _currentMonthReport['worked_hour'] = raw.isNotEmpty ? raw : "-";
    }
    // Don't notify here - let the parent method handle it
  }

  String getProdHour(int value) {
    // value is already in minutes, so convert directly to hours and minutes
    int hour = value ~/ 60;
    int minGone = (value % 60).toInt();

    print("$hour hr $minGone min");
    _todayReport['production_hour'] = "$hour hr $minGone min";

    // Calculate percentage: total minutes worked / total working minutes (8 hours * 60 minutes)
    double totalWorkingMinutes = Constant.TOTAL_WORKING_HOUR * 60.0;
    double hr = value / totalWorkingMinutes;

    _todayReport['production_percent'] = hr > 1.0 ? 1.0 : hr;
    // Don't notify here - let the parent method handle it
    return "$hour hr $minGone min";
  }
}
