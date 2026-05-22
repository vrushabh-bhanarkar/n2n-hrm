class User {
  User({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.avatar,
    required this.onlineStatus,
    required this.department,
    required this.branch,
    required this.dob,
    required this.gender,
    required this.workspace_type,
  });

  factory User.fromJson(dynamic json) {
    return User(
        id: json['id'] ?? 0,
        name: json['name']?.toString() ?? "",
        email: json['email']?.toString() ?? "",
        username: json['username']?.toString() ?? "",
        avatar: json['avatar']?.toString() ?? "",
        onlineStatus: _toBool(json['online_status']),
        department: json['department']?.toString() ?? "",
        branch: json['branch']?.toString() ?? "",
        dob: json['dob']?.toString() ?? "",
        gender: json['gender']?.toString() ?? "",
        workspace_type: json['workspace_type']?.toString() ?? "");
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  int id;
  String name;
  String email;
  String username;
  String avatar;
  bool onlineStatus;
  String workspace_type;
  String department;
  String branch;
  String dob;
  String gender;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['name'] = name;
    map['email'] = email;
    map['username'] = username;
    map['avatar'] = avatar;
    map['online_status'] = onlineStatus;
    return map;
  }
}
