import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/model/chat/conversation.dart';
import 'package:cnattendance/model/chat/message.dart';
import 'package:cnattendance/services/chat/chat_service.dart';
import 'package:cnattendance/services/chat/message_polling_service.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({Key? key, required this.conversation}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  MessagePollingService? _pollingService;
  late Conversation _conversation;
  static final RegExp _urlRegex =
      RegExp(r'https?:\/\/[^\s]+|www\.[^\s]+', caseSensitive: false);
  final Set<String> _failedImageUrlsLogged = <String>{};

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _loadMessages();
    _setupPolling();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pollingService?.dispose();
    super.dispose();
  }

  void _setupPolling() {
    _pollingService = MessagePollingService(
      onNewMessages: (newMessages) {
        if (!mounted) return;
        setState(() {
          // Add new messages if they're not already in the list
          for (final message in newMessages) {
            if (!_messages.any((m) => m.id == message.id)) {
              _messages.add(message);
            }
          }
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        _scrollToBottom();
      },
      onError: (error) {
        _showSnackBar('Connection error: $error', Colors.orange);
      },
    );
    // _loadMessages() already fetches initial data in initState, so avoid
    // an immediate duplicate polling request.
    _pollingService!.startPollingWithoutInitialLoad(
      _conversation.id,
      interval: const Duration(seconds: 30),
    );
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final messages = await ChatService.getMessages(_conversation.id);
      // Ensure messages are sorted oldest -> newest
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Try to refresh conversation details (participant names/count) from server
      try {
        final conversations = await ChatService.getConversations();
        final updated = conversations.firstWhere(
          (c) => c.id == _conversation.id,
          orElse: () => _conversation,
        );
        _conversation = updated;
      } catch (_) {
        // Ignore errors here; still show messages
      }

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _pollingService?.setInitialMessages(messages);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndSendAttachment({required bool imageOnly}) async {
    try {
      File? file;
      if (imageOnly) {
        final picked =
            await ImagePicker().pickImage(source: ImageSource.gallery);
        if (picked == null) return;
        file = File(picked.path);
      } else {
        final result = await FilePicker.platform.pickFiles(type: FileType.any);
        if (result == null || result.files.single.path == null) return;
        file = File(result.files.single.path!);
      }

      setState(() => _isSending = true);
      final message = await ChatService.sendAttachment(
        conversationId: _conversation.id,
        file: file,
        isGroup: _conversation.isGroup,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showSnackBar('Failed to send attachment: $e', Colors.red);
    }
  }

  void _showAttachmentPicker() {
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

  Future<void> _sendMessage() async {
    if (!mounted || _messageController.text.trim().isEmpty || _isSending) {
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      final message = _conversation.isGroup
          ? await ChatService.sendGroupMessage(
              conversationId: _conversation.id,
              message: messageText,
            )
          : await ChatService.sendMessage(
              conversationId: _conversation.id,
              message: messageText,
            );

      if (!mounted) return;
      setState(() {
        _messages.add(message);
        // keep list sorted
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showSnackBar('Failed to send message: $e', Colors.red);
      // Restore the message text
      _messageController.text = messageText;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Converts a relative URL to an absolute one using the configured base URL.
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

    // Try the message text: full URL via regex, or relative/bare-filename paths
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
    // Strip query params before checking the extension
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

  bool _isPdfUrl(String url) {
    return url.toLowerCase().contains('.pdf');
  }

  Future<void> _openAttachment(String rawUrl) async {
    final normalized =
        rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
            ? rawUrl
            : 'https://$rawUrl';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      _showSnackBar('Invalid file link', Colors.red);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showSnackBar('Unable to open attachment', Colors.red);
    }
  }

  void _showAttachments({required bool images}) {
    final urls = <String>[];
    for (final message in _messages) {
      final url = _extractAttachmentUrl(message);
      if (url == null) continue;
      if (images && _isImageUrl(url)) urls.add(url);
      if (!images && !_isImageUrl(url)) urls.add(url);
    }

    if (urls.isEmpty) {
      _showSnackBar(
          images ? 'No images found' : 'No files found', Colors.orange);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: urls.length,
        itemBuilder: (_, i) {
          final url = urls[i];
          return ListTile(
            leading: Icon(images ? Icons.image : Icons.attach_file),
            title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () {
              Navigator.pop(ctx);
              _openAttachment(url);
            },
          );
        },
      ),
    );
  }

  void _insertMention() {
    // Build member list: prefer participantNames, fall back to unique senders
    List<String> members = [];
    if (_conversation.participantNames.trim().isNotEmpty) {
      members = _conversation.participantNames
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }
    if (members.isEmpty) {
      // Derive participants from already-loaded messages
      members = _messages
          .map((m) => m.sender.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
    }
    if (members.isEmpty) {
      _showSnackBar('No members available to tag', Colors.orange);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: members.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(members[i]),
          onTap: () {
            final current = _messageController.text;
            _messageController.text = '$current@${members[i]} ';
            _messageController.selection =
                TextSelection.collapsed(offset: _messageController.text.length);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return 'Today';
    } else if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  bool _shouldShowDateHeader(int index) {
    if (index == 0) return true;

    final currentMessage = _messages[index];
    final previousMessage = _messages[index - 1];

    return currentMessage.createdAt.day != previousMessage.createdAt.day ||
        currentMessage.createdAt.month != previousMessage.createdAt.month ||
        currentMessage.createdAt.year != previousMessage.createdAt.year;
  }

  Widget _buildDateHeader(DateTime dateTime) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Text(
            _formatDateHeader(dateTime),
            style: const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(Message message, bool isMe) {
    final attachmentUrl = _extractAttachmentUrl(message);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe && _conversation.isGroup)
              Text(
                message.sender.name,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.white70 : Colors.blue,
                ),
              ),
            if (!isMe && _conversation.isGroup) const SizedBox(height: 4.0),
            if (attachmentUrl != null &&
                (message.type == 'image' || _isImageUrl(attachmentUrl)))
              GestureDetector(
                onTap: () => _openAttachment(attachmentUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    attachmentUrl,
                    width: 180,
                    height: 140,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : SizedBox(
                            width: 180,
                            height: 140,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          ),
                    errorBuilder: (_, error, __) {
                      if (_failedImageUrlsLogged.add(attachmentUrl)) {
                        debugPrint(
                          'Image.network failed for $attachmentUrl: $error',
                        );
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image,
                              color: isMe ? Colors.white : Colors.black87),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              message.message,
                              style: TextStyle(
                                fontSize: 14.0,
                                color: isMe ? Colors.white70 : Colors.black54,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              )
            else if (attachmentUrl != null &&
                (message.type == 'file' ||
                    message.type == 'image' ||
                    message.type != 'text' ||
                    _isPdfUrl(attachmentUrl)))
              InkWell(
                onTap: () => _openAttachment(attachmentUrl),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPdfUrl(attachmentUrl)
                          ? Icons.picture_as_pdf
                          : Icons.attach_file,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isPdfUrl(attachmentUrl) ? 'Open PDF' : 'Open file',
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                message.message,
                style: TextStyle(
                  fontSize: 16.0,
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
            const SizedBox(height: 4.0),
            Text(
              _formatMessageTime(message.createdAt),
              style: TextStyle(
                fontSize: 12.0,
                color: isMe ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
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
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _conversation.name,
                style: const TextStyle(fontSize: 18.0),
                overflow: TextOverflow.ellipsis,
              ),
              if (_conversation.isGroup)
                Text(
                  _conversation.participantNames.isNotEmpty
                      ? '${_conversation.participantNames} (${_conversation.participants.length})'
                      : '${_conversation.participants.length} members',
                  style: const TextStyle(fontSize: 12.0),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadMessages,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64.0,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          'Error loading messages',
                          style: TextStyle(
                            fontSize: 18.0,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16.0),
                        ElevatedButton(
                          onPressed: _loadMessages,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: _messages.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 64.0,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16.0),
                                    Text(
                                      'No messages yet',
                                      style: TextStyle(
                                        fontSize: 18.0,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      'Send a message to start the conversation',
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(8.0),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final message = _messages[index];
                                  final currentUserId =
                                      context.watch<PrefProvider>().userId;
                                  final isMe = message.senderId.toString() ==
                                      currentUserId;

                                  return Column(
                                    children: [
                                      if (_shouldShowDateHeader(index))
                                        _buildDateHeader(message.createdAt),
                                      _buildMessage(message, isMe),
                                    ],
                                  );
                                },
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey[300]!,
                              blurRadius: 4.0,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _isSending ? null : _showAttachmentPicker,
                              icon: const Icon(Icons.attach_file),
                            ),
                            IconButton(
                              onPressed: _insertMention,
                              icon: const Icon(Icons.alternate_email),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24.0),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                ),
                                maxLines: null,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            FloatingActionButton.small(
                              onPressed: _isSending ? null : _sendMessage,
                              backgroundColor:
                                  _isSending ? Colors.grey : Colors.blue,
                              child: _isSending
                                  ? const SizedBox(
                                      width: 16.0,
                                      height: 16.0,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
