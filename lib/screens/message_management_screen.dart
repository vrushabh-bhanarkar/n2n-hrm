import 'package:flutter/material.dart';
import 'package:cnattendance/services/hrm_data_service.dart';
import 'package:cnattendance/widget/radialDecoration.dart';

class MessageManagementScreen extends StatefulWidget {
  const MessageManagementScreen({Key? key}) : super(key: key);

  @override
  State<MessageManagementScreen> createState() =>
      _MessageManagementScreenState();
}

class _MessageManagementScreenState extends State<MessageManagementScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _users = [];
  List<String> _selectedRecipients = [];
  String _selectedType = 'general';
  String _selectedPriority = 'normal';
  bool _isLoading = false;
  bool _isBroadcast = false;

  final List<String> _messageTypes = [
    'general',
    'announcement',
    'welcome',
    'achievement',
    'review',
    'reminder',
    'urgent'
  ];

  final List<String> _priorities = ['low', 'normal', 'high', 'urgent'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await HRMDataService.getUsers();
      final messages = await HRMDataService.getAllMessages();

      setState(() {
        _users = users;
        _messages = messages;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
          title: const Text('Message Management'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCreateMessageCard(),
                    const SizedBox(height: 24),
                    _buildMessagesListCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCreateMessageCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Message',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Message Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Message Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Message Body
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Message Body',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter message content';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Message Type and Priority Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _messageTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPriority,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: _priorities.map((priority) {
                        return DropdownMenuItem(
                          value: priority,
                          child: Text(
                            priority.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value!;
                        });
                      },
                      selectedItemBuilder: (context) {
                        return _priorities
                            .map(
                              (priority) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  priority.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Broadcast Switch
              SwitchListTile(
                title: const Text('Send to All Users'),
                subtitle: const Text('Enable to send as broadcast message'),
                value: _isBroadcast,
                onChanged: (value) {
                  setState(() {
                    _isBroadcast = value;
                    if (value) {
                      _selectedRecipients.clear();
                    }
                  });
                },
                activeThumbColor: Colors.indigo,
              ),

              // Recipients Selection (only if not broadcast)
              if (!_isBroadcast) ...[
                const SizedBox(height: 8),
                Text(
                  'Select Recipients:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final isSelected =
                          _selectedRecipients.contains(user['id']);

                      return CheckboxListTile(
                        title: Text(user['name']),
                        subtitle: Text(user['position']),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedRecipients.add(user['id']);
                            } else {
                              _selectedRecipients.remove(user['id']);
                            }
                          });
                        },
                        activeColor: Colors.indigo,
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  label: Text(_isBroadcast ? 'Send Broadcast' : 'Send Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesListCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Messages (${_messages.length})',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: _archiveExpiredMessages,
                  icon: const Icon(Icons.archive),
                  label: const Text('Archive Expired'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_messages.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No messages found'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _messages.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageTile(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> message) {
    final createdAt = message['createdAt'] != null
        ? (message['createdAt'] is DateTime
            ? message['createdAt'] as DateTime
            : DateTime.now())
        : DateTime.now();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getPriorityColor(message['priority'] ?? 'normal'),
        child: Icon(
          _getMessageTypeIcon(message['type'] ?? 'general'),
          color: Colors.white,
        ),
      ),
      title: Text(
        message['title'] ?? 'No Title',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message['body'] ?? 'No Content',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${(message['recipients'] as List?)?.length ?? 0} recipients',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleMessageAction(value, message),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getMessageTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'announcement':
        return Icons.campaign;
      case 'welcome':
        return Icons.waving_hand;
      case 'achievement':
        return Icons.celebration;
      case 'review':
        return Icons.rate_review;
      case 'reminder':
        return Icons.alarm;
      case 'urgent':
        return Icons.warning;
      default:
        return Icons.message;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isBroadcast && _selectedRecipients.isEmpty) {
      _showErrorSnackBar('Please select at least one recipient');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? messageId;

      if (_isBroadcast) {
        messageId = await HRMDataService.addBroadcastMessage({
          'title': _titleController.text,
          'content': _bodyController.text,
          'sender': 'admin', // You can get this from user session
          'type': _selectedType,
          'priority': _selectedPriority,
        });
      } else {
        messageId = await HRMDataService.addMessage({
          'title': _titleController.text,
          'content': _bodyController.text,
          'sender': 'admin', // You can get this from user session
          'recipients': _selectedRecipients,
          'type': _selectedType,
          'priority': _selectedPriority,
        });
      }

      if (messageId != null) {
        _showSuccessSnackBar('Message sent successfully!');
        _clearForm();
        _loadData(); // Refresh the messages list
      } else {
        _showErrorSnackBar('Failed to send message');
      }
    } catch (e) {
      _showErrorSnackBar('Error sending message: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleMessageAction(
      String action, Map<String, dynamic> message) async {
    switch (action) {
      case 'delete':
        final confirmed = await _showConfirmDialog(
          'Delete Message',
          'Are you sure you want to delete this message?',
        );
        if (confirmed) {
          final success = await HRMDataService.deleteMessage(message['id']);
          if (success) {
            _showSuccessSnackBar('Message deleted successfully');
            _loadData();
          } else {
            _showErrorSnackBar('Failed to delete message');
          }
        }
        break;
    }
  }

  Future<void> _archiveExpiredMessages() async {
    final success = await HRMDataService.archiveExpiredMessages();
    if (success) {
      _showSuccessSnackBar('Expired messages archived successfully');
      _loadData();
    } else {
      _showErrorSnackBar('Failed to archive expired messages');
    }
  }

  void _clearForm() {
    _titleController.clear();
    _bodyController.clear();
    setState(() {
      _selectedRecipients.clear();
      _selectedType = 'general';
      _selectedPriority = 'normal';
      _isBroadcast = false;
    });
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
