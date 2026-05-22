import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cnattendance/services/chat/chat_service.dart';
import 'package:cnattendance/services/chat/message_polling_service.dart';
import 'package:cnattendance/services/fcm_service.dart';
import 'package:cnattendance/model/chat/conversation.dart';
import 'package:cnattendance/model/chat/message.dart';
import 'package:cnattendance/model/member.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';

class ProjectChatScreen extends StatefulWidget {
  final int projectId;
  final String projectName;
  final List<Member> leaders;
  final List<Member> members;
  final int? conversationId;

  const ProjectChatScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
    required this.leaders,
    required this.members,
    this.conversationId,
  }) : super(key: key);

  @override
  _ProjectChatScreenState createState() => _ProjectChatScreenState();
}

class _ProjectChatScreenState extends State<ProjectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final MessagePollingService _pollingService;

  List<Message> messages = [];
  Conversation? projectConversation;
  bool isLoading = true;
  bool isSending = false;
  int? currentUserId;
  List<String> _mentionSuggestions = [];

  static final RegExp _urlRegex =
      RegExp(r'https?:\/\/[^\s]+|www\.[^\s]+', caseSensitive: false);

  /// Converts a relative URL to absolute using the configured base URL.
  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('www.')) return 'https://$trimmed';

    final base = Constant.MAIN_URL.endsWith('/')
        ? Constant.MAIN_URL.substring(0, Constant.MAIN_URL.length - 1)
        : Constant.MAIN_URL;
    return trimmed.startsWith('/') ? '$base$trimmed' : '$base/$trimmed';
  }

  String? _extractAttachmentUrl(Message message) {
    final metadata = message.metadata;
    if (metadata != null) {
      for (final key in const [
        'attachment_url',
        'file_url',
        'file_path',
        'url',
        'attachment',
        'path',
        'image'
      ]) {
        final value = metadata[key];
        if (value is String && value.trim().isNotEmpty) {
          return _normalizeUrl(value.trim());
        }
      }

      final attachment = metadata['attachment'];
      if (attachment is Map && attachment['url'] is String) {
        return _normalizeUrl((attachment['url'] as String).trim());
      }

      final file = metadata['file'];
      if (file is Map && file['url'] is String) {
        return _normalizeUrl((file['url'] as String).trim());
      }
    }
    // Full URL via regex, or relative/bare-filename paths
    final text = message.message.trim();
    final match = _urlRegex.firstMatch(text);
    if (match != null) return _normalizeUrl(match.group(0)!);
    if (message.type == 'image' || message.type == 'file') {
      if (text.startsWith('/')) return _normalizeUrl(text);
      // Bare filename with no path (e.g. "1000378538.jpg") — prepend chat uploads path
      if (!text.contains('/') && (_isImageUrl(text) || _isPdfUrl(text))) {
        return _normalizeUrl('uploads/chat/$text');
      }
    }
    return null;
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  bool _isPdfUrl(String url) => url.toLowerCase().contains('.pdf');

  @override
  void initState() {
    super.initState();

    // Initialize polling service with comprehensive notification support
    _pollingService = MessagePollingService(
      projectName: widget.projectName, // Pass project name for notifications
      projectId: widget.projectId, // Pass project ID for backend notifications
      conversationId: widget.conversationId,
      onNewMessages: (newMessages) {
        if (!mounted) return;
        setState(() {
          for (final message in newMessages) {
            if (!messages.any((m) => m.id == message.id)) {
              messages.add(message);
            }
          }
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        _scrollToBottom();
      },
      onError: (error) {
        print('Polling error: $error');
      },
    );

    _initializeChat();
  }

  @override
  void dispose() {
    _pollingService.stopPolling();
    _messageController.dispose();
    _scrollController.dispose();

    // Clear chat screen context to re-enable notifications
    FCMService.setChatScreenContext(isInChat: false);

    // Unsubscribe from project chat notifications when leaving
    if (widget.projectId > 0) {
      FCMService.unsubscribeFromProjectChat(widget.projectId);
    }

    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get current user ID
      final prefs = Preferences();
      currentUserId = await prefs.getUserId();

      // Subscribe to project chat notifications
      if (widget.projectId > 0) {
        await FCMService.subscribeToProjectChat(widget.projectId);
      }

      if (widget.conversationId != null && widget.conversationId! > 0) {
        projectConversation = Conversation(
          id: widget.conversationId!,
          name: widget.projectName,
          type: 'group',
          participants: [],
          participantNames: '',
        );

        await _loadMessages();

        _pollingService.setInitialMessages(messages);
        _pollingService.startPollingWithoutInitialLoad(projectConversation!.id);

        FCMService.setChatScreenContext(
          conversationId: projectConversation!.id.toString(),
          isInChat: true,
        );

        setState(() {
          isLoading = false;
        });
        return;
      }

      // Get all conversations and find the project conversation
      final conversations = await ChatService.getConversations();

      // Find conversation that matches the project name (auto-created by backend)
      projectConversation = conversations.firstWhere(
        (conv) =>
            conv.name == widget.projectName ||
            conv.name == '${widget.projectName} Team Chat',
        orElse: () => throw Exception('Project conversation not found'),
      );

      // Load initial messages
      await _loadMessages();

      // Set the initial message state for polling service
      _pollingService.setInitialMessages(messages);

      // Start polling for new messages (without initial load since we just loaded)
      _pollingService.startPollingWithoutInitialLoad(projectConversation!.id);

      // Set chat screen context to suppress notifications for this conversation
      print('🔧 Setting chat context - Conversation ID: ${projectConversation!.id} (type: ${projectConversation!.id.runtimeType})');
      FCMService.setChatScreenContext(
        conversationId: projectConversation!.id.toString(),
        isInChat: true,
      );

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      // If no conversation found, show error - backend should have created it
      print('Project conversation not found: $e');
      Get.snackbar(
        'Chat Not Available',
        'Project conversation not found. Please contact administrator.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMessages() async {
    if (projectConversation == null) return;

    try {
      final loadedMessages =
          await ChatService.getMessages(projectConversation!.id);
      // Sort oldest first so newest appears at the bottom of the list
      loadedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (!mounted) return;
      setState(() {
        messages = loadedMessages;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || projectConversation == null || isSending)
      return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      isSending = true;
    });

    try {
      final sentMessage = await ChatService.sendGroupMessage(
        conversationId: projectConversation!.id,
        message: messageText,
      );

      if (!mounted) return;
      // Add the message to the list
      setState(() {
        if (!messages.any((m) => m.id == sentMessage.id)) {
          messages.add(sentMessage);
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }
      });
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      if (!mounted) return;
      Get.snackbar(
        'Error',
        'Failed to send message. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndSendAttachment({required bool imageOnly}) async {
    if (projectConversation == null) return;
    try {
      File? file;
      if (imageOnly) {
        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (picked == null) return;
        file = File(picked.path);
      } else {
        final result = await FilePicker.platform.pickFiles(type: FileType.any);
        if (result == null || result.files.single.path == null) return;
        file = File(result.files.single.path!);
      }

      setState(() => isSending = true);
      final message = await ChatService.sendAttachment(
        conversationId: projectConversation!.id,
        file: file,
        isGroup: true,
      );
      if (!mounted) return;
      setState(() {
        messages.add(message);
        isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => isSending = false);
      Get.snackbar('Error', 'Failed to send attachment: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _insertMention() {
    final allMembers = [
      ...widget.leaders.map((m) => m.name),
      ...widget.members.map((m) => m.name),
    ].toSet().toList();
    if (allMembers.isEmpty) return;
    // Insert @ at cursor to trigger suggestion list
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    final pos = cursor >= 0 ? cursor : text.length;
    final newText = '${text.substring(0, pos)}@${text.substring(pos)}';
    _messageController.text = newText;
    _messageController.selection = TextSelection.collapsed(offset: pos + 1);
    _onTextChanged(newText);
  }

  void _showAttachmentPicker({bool imageOnly = false}) {
    if (imageOnly) {
      _pickAndSendAttachment(imageOnly: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Send Image'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendAttachment(imageOnly: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Send File'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendAttachment(imageOnly: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onTextChanged(String value) {
    final cursor = _messageController.selection.baseOffset;
    final text = cursor >= 0 ? value.substring(0, cursor) : value;
    final atIndex = text.lastIndexOf('@');
    if (atIndex >= 0) {
      final query = text.substring(atIndex + 1).toLowerCase();
      final allMembers = [
        ...widget.leaders.map((m) => m.name),
        ...widget.members.map((m) => m.name),
      ].toSet().toList();
      final filtered = allMembers
          .where((name) => name.toLowerCase().contains(query))
          .toList();
      setState(() => _mentionSuggestions = filtered);
    } else {
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
    }
  }

  void _selectMention(String name) {
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    final beforeCursor = cursor >= 0 ? text.substring(0, cursor) : text;
    final afterCursor = cursor >= 0 ? text.substring(cursor) : '';
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex >= 0) {
      final newText = '${beforeCursor.substring(0, atIndex)}@$name $afterCursor';
      _messageController.text = newText;
      _messageController.selection = TextSelection.collapsed(
        offset: atIndex + name.length + 2,
      );
    }
    setState(() => _mentionSuggestions = []);
  }

  Widget _buildMentionSuggestions() {
    if (_mentionSuggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _mentionSuggestions.length,
        itemBuilder: (_, i) {
          final name = _mentionSuggestions[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[600],
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(name),
            onTap: () => _selectMention(name),
          );
        },
      ),
    );
  }

  Future<void> _openAttachment(String rawUrl) async {
    final normalized = rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
        ? rawUrl
        : 'https://$rawUrl';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      Get.snackbar('Error', 'Unable to open attachment',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  message.sender.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (_) {
                    if (message.type == 'image' || message.type == 'file') {
                      final attachmentUrl = _extractAttachmentUrl(message);
                      if (attachmentUrl != null &&
                        (message.type == 'image' || _isImageUrl(attachmentUrl))) {
                        return GestureDetector(
                          onTap: () => _openAttachment(attachmentUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              attachmentUrl,
                              width: 200,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image,
                                      color: isMe ? Colors.white : Colors.black87,
                                      size: 18),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      message.message,
                                      style: TextStyle(
                                        color: isMe ? Colors.white : Colors.black87,
                                        fontSize: 14,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      // File or image without an inline-renderable URL
                      return InkWell(
                        onTap: attachmentUrl != null
                            ? () => _openAttachment(attachmentUrl)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isPdfUrl(attachmentUrl ?? '')
                                  ? Icons.picture_as_pdf
                                  : message.type == 'image'
                                      ? Icons.image
                                      : Icons.attach_file,
                              color: isMe ? Colors.white : Colors.black87,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                message.message,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Text(
                      message.message,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    );
                  }),
                  SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            widget.projectName,
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              onPressed: isSending ? null : () => _showAttachmentPicker(imageOnly: true),
              icon: Icon(Icons.photo, color: Colors.white),
              tooltip: 'Send Image',
            ),
            IconButton(
              onPressed: isSending ? null : () => _showAttachmentPicker(imageOnly: false),
              icon: Icon(Icons.attach_file, color: Colors.white),
              tooltip: 'Send File',
            ),
            IconButton(
              onPressed: _insertMention,
              icon: Icon(Icons.alternate_email, color: Colors.white),
              tooltip: 'Mention',
            ),
            IconButton(
              onPressed: () {
                // Show team members
                _showTeamMembers();
              },
              icon: Icon(Icons.people, color: Colors.white),
            ),
          ],
        ),
        body: SafeArea(
          child: isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    // Messages list
                    Expanded(
                      child: messages.isEmpty
                          ? Center(
                              child: Text(
                                'No messages yet. Start the conversation!',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                return _buildMessageBubble(messages[index]);
                              },
                            ),
                    ),
                    // Mention suggestions
                    _buildMentionSuggestions(),
                    // Message input
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  border: InputBorder.none,
                                ),
                                onChanged: _onTextChanged,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.blue[600],
                            child: isSending
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(Icons.send, color: Colors.white),
                                    onPressed: _sendMessage,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showTeamMembers() {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: RadialDecoration(),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Team Members',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (widget.leaders.isNotEmpty) ...[
                  Text(
                    'Project Leaders',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...widget.leaders.map((leader) => Card(
                        color: Colors.white10,
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[600],
                            child: Text(
                              leader.name.isNotEmpty ? leader.name[0].toUpperCase() : 'L',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            leader.name.isNotEmpty ? leader.name : 'Unknown Leader',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            leader.post.isNotEmpty ? leader.post : 'Leader',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )),
                  SizedBox(height: 16),
                ],
                if (widget.members.isNotEmpty) ...[
                  Text(
                    'Team Members',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...widget.members.map((member) => Card(
                        color: Colors.white10,
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[400],
                            child: Text(
                              member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            member.name.isNotEmpty ? member.name : 'Unknown Member',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            member.post.isNotEmpty ? member.post : 'Member',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: false,
    );
  }
}
