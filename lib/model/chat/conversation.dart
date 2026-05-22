import 'user.dart';
import 'message.dart';

class Conversation {
  final int id;
  final String name;
  final String type;
  final List<int> participants;
  final String participantNames;
  final User? createdBy;
  final bool isMonitoring;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime? lastMessageAt;

  Conversation({
    required this.id,
    required this.name,
    required this.type,
    required this.participants,
    required this.participantNames,
    this.createdBy,
    this.isMonitoring = false,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.parse(json['id'].toString()) : 0),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'group',
      participants: json['participants'] != null 
          ? List<int>.from(json['participants'].map((x) => x is int ? x : (x != null ? int.parse(x.toString()) : 0)))
          : [],
      participantNames: json['participant_names']?.toString() ?? '',
      createdBy: json['creator'] != null 
          ? User.fromJson(json['creator']) 
          : (json['created_by'] != null && json['created_by'] is Map
              ? User.fromJson(json['created_by'])
              : null),
      isMonitoring: json['is_monitoring'] == true,
      lastMessage: json['last_message'] != null 
          ? Message.fromJson(json['last_message']) 
          : null,
      unreadCount: json['unread_count'] is int 
          ? json['unread_count'] 
          : int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
      lastMessageAt: json['last_message_at'] != null 
          ? DateTime.tryParse(json['last_message_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'participants': participants,
      'participant_names': participantNames,
      'created_by': createdBy?.toJson(),
      'is_monitoring': isMonitoring,
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'last_message_at': lastMessageAt?.toIso8601String(),
    };
  }

  bool get isGroup => type == 'group';
  bool get isDirect => type == 'direct' || type == 'private';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}