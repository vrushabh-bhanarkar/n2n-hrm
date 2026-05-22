import 'user.dart';

class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final User sender;
  final Map<String, dynamic>? metadata;

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? DateTime.now();
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.message,
    required this.type,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    required this.sender,
    this.metadata,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final senderJson = json['sender'];
    final senderName = json['sender_name']?.toString() ??
        json['user_name']?.toString() ??
        json['name']?.toString() ??
        'Unknown User';

    return Message(
      id: _parseInt(json['id']),
      conversationId: _parseInt(json['conversation_id']),
      senderId: _parseInt(json['sender_id']),
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      isRead: json['is_read'] == true,
      readAt: json['read_at'] != null ? _parseDate(json['read_at']) : null,
      createdAt: _parseDate(json['created_at'] ?? json['updated_at']),
      sender: senderJson is Map
          ? User.fromJson(Map<String, dynamic>.from(senderJson))
          : User(id: _parseInt(json['sender_id']), name: senderName),
      metadata: _parseMetadata(json),
    );
  }

  /// Builds metadata from the JSON response. Checks the nested `metadata` object
  /// first, then falls back to common top-level attachment URL fields returned
  /// by some backends (e.g. `attachment_url`, `file_url`, `path`, `url`).
  static Map<String, dynamic>? _parseMetadata(Map<String, dynamic> json) {
    if (json['metadata'] is Map) {
      final metadata = Map<String, dynamic>.from(json['metadata']);

      // Ensure a canonical `url` key exists for UI consumers.
      if (metadata['url'] == null || metadata['url'].toString().trim().isEmpty) {
        for (final key in const [
          'attachment_url',
          'file_url',
          'file_path',
          'path',
          'attachment',
          'image',
        ]) {
          final value = metadata[key];
          if (value is String && value.trim().isNotEmpty) {
            metadata['url'] = value.trim();
            break;
          }
        }

        final attachment = metadata['attachment'];
        if ((metadata['url'] == null || metadata['url'].toString().trim().isEmpty) &&
            attachment is Map &&
            attachment['url'] is String &&
            (attachment['url'] as String).trim().isNotEmpty) {
          metadata['url'] = (attachment['url'] as String).trim();
        }

        final file = metadata['file'];
        if ((metadata['url'] == null || metadata['url'].toString().trim().isEmpty) &&
            file is Map &&
            file['url'] is String &&
            (file['url'] as String).trim().isNotEmpty) {
          metadata['url'] = (file['url'] as String).trim();
        }
      }

      return metadata;
    }

    // Collect a URL from common top-level fields
    String? attachmentUrl;
    for (final key in const [
      'attachment_url',
      'file_url',
      'file_path',
      'path',
      'url',
      'attachment',
    ]) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) {
        attachmentUrl = v.trim();
        break;
      }
    }

    // Some backends return nested objects for attachment metadata.
    if (attachmentUrl == null) {
      final attachment = json['attachment'];
      if (attachment is Map &&
          attachment['url'] is String &&
          (attachment['url'] as String).trim().isNotEmpty) {
        attachmentUrl = (attachment['url'] as String).trim();
      }
    }

    if (attachmentUrl == null) {
      final file = json['file'];
      if (file is Map &&
          file['url'] is String &&
          (file['url'] as String).trim().isNotEmpty) {
        attachmentUrl = (file['url'] as String).trim();
      }
    }

    if (attachmentUrl == null) {
      final attachments = json['attachments'];
      if (attachments is List && attachments.isNotEmpty) {
        final first = attachments.first;
        if (first is Map) {
          for (final key in const ['attachment_url', 'file_url', 'url', 'path']) {
            final value = first[key];
            if (value is String && value.trim().isNotEmpty) {
              attachmentUrl = value.trim();
              break;
            }
          }
        }
      }
    }

    // If the message text itself is a URL or a relative path (many backends
    // store the file URL – full or relative – in the `message` field for
    // image/file-type messages).
    if (attachmentUrl == null) {
      final type = json['type']?.toString() ?? '';
      final msg = json['message']?.toString().trim() ?? '';
      if ((type == 'image' || type == 'file') &&
          (msg.startsWith('http://') ||
              msg.startsWith('https://') ||
              msg.startsWith('/'))) {
        attachmentUrl = msg;
      }
    }

    if (attachmentUrl == null) return null;

    return {
      'url': attachmentUrl,
      if (json['mime_type'] is String) 'mime': json['mime_type'],
      if (json['mime'] is String) 'mime': json['mime'],
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message': message,
      'type': type,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'sender': sender.toJson(),
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
