class ProjectLeader {
  String avatar;
  int id;
  String name;
  String post;

  ProjectLeader(
      {required this.avatar,
      required this.id,
      required this.name,
      required this.post});

  factory ProjectLeader.fromJson(Map<String, dynamic> json) {
    return ProjectLeader(
      avatar: json['avatar']?.toString() ?? "",
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? "",
      post: json['post']?.toString() ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['avatar'] = this.avatar;
    data['id'] = this.id;
    data['name'] = this.name;
    data['post'] = this.post;
    return data;
  }
}
