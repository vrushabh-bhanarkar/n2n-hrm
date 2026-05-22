class EmployeeTodayAttendance {
  EmployeeTodayAttendance({
    required this.checkInAt,
    required this.checkOutAt,
    required this.productionTime,
    required this.allowedBreakTime,
    required this.breakUsedTime,
    required this.remainingBreakTime,
    required this.isOnBreak,
  });

  factory EmployeeTodayAttendance.fromJson(dynamic json) {
    return EmployeeTodayAttendance(
        checkInAt: json['check_in_at'].toString(),
        checkOutAt: json['check_out_at'].toString(),
        productionTime: _toInt(json['productive_time_in_min']),
        allowedBreakTime: _toInt(json['allowed_break_time_in_min']),
        breakUsedTime: _toInt(json['break_used_in_min']),
        remainingBreakTime: _toInt(json['remaining_break_time_in_min']),
        isOnBreak: json['is_on_break'] == true);
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  int productionTime;
  int allowedBreakTime;
  int breakUsedTime;
  int remainingBreakTime;
  bool isOnBreak;
  String checkInAt;
  String checkOutAt;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['check_in_at'] = checkInAt;
    map['check_out_at'] = checkOutAt;
    map['productive_time_in_min'] = productionTime;
    map['allowed_break_time_in_min'] = allowedBreakTime;
    map['break_used_in_min'] = breakUsedTime;
    map['remaining_break_time_in_min'] = remainingBreakTime;
    map['is_on_break'] = isOnBreak;
    return map;
  }
}
