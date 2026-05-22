class User {
  final int id;
  final String name;
  final String? email;
  final String? avatar;
  final int? departmentId;
  final int? roleId;
  final int? postId;

  User({
    required this.id,
    required this.name,
    this.email,
    this.avatar,
    this.departmentId,
    this.roleId,
    this.postId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.parse(json['id'].toString()) : 0),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      avatar: json['avatar']?.toString(),
      departmentId: json['department_id'] is int 
          ? json['department_id'] 
          : int.tryParse(json['department_id']?.toString() ?? ''),
      roleId: json['role_id'] is int 
          ? json['role_id'] 
          : int.tryParse(json['role_id']?.toString() ?? ''),
      postId: json['post_id'] is int 
          ? json['post_id'] 
          : int.tryParse(json['post_id']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'department_id': departmentId,
      'role_id': roleId,
      'post_id': postId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}