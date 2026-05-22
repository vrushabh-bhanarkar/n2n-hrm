import 'package:flutter/material.dart';
import 'package:cnattendance/services/hrm_data_service.dart';

class HRMDataDemoScreen extends StatefulWidget {
  const HRMDataDemoScreen({Key? key}) : super(key: key);

  @override
  State<HRMDataDemoScreen> createState() => _HRMDataDemoScreenState();
}

class _HRMDataDemoScreenState extends State<HRMDataDemoScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _attendance = [];
  Map<String, dynamic>? _settings;
  bool _isLoading = false;
  String _selectedUserId = '';

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
      // Load users
      _users = await HRMDataService.getUsers();
      
      // Load company settings
      _settings = await HRMDataService.getCompanySettings();
      
      // If we have users, load data for the first user
      if (_users.isNotEmpty) {
        _selectedUserId = _users.first['id'];
        await _loadUserData(_selectedUserId);
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData(String userId) async {
    try {
      int userIdInt = int.tryParse(userId) ?? 1; // Default to 1 if parsing fails
      _messages = await HRMDataService.getMessagesForUser(userIdInt);
      _attendance = await HRMDataService.getAttendanceForUser(userIdInt, days: 7);
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HRM Data Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Company Info
                  if (_settings != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Company Information',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Name: ${_settings!['company']['name']}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              'Address: ${_settings!['company']['address']['street']}, ${_settings!['company']['address']['city']}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Working Hours: ${_settings!['workingHours']['monday']['start']} - ${_settings!['workingHours']['monday']['end']}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Users Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Employees (${_users.length})',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (_users.isEmpty)
                            const Text('No employees found')
                          else
                            Column(
                              children: _users.map((user) {
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(user['name'].substring(0, 1)),
                                  ),
                                  title: Text(user['name']),
                                  subtitle: Text('${user['position']} - ${user['department']}'),
                                  trailing: user['isActive']
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : const Icon(Icons.cancel, color: Colors.red),
                                  onTap: () async {
                                    setState(() {
                                      _selectedUserId = user['id'];
                                      _isLoading = true;
                                    });
                                    await _loadUserData(user['id']);
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Messages Section
                  if (_selectedUserId.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messages for ${_users.firstWhere((u) => u['id'] == _selectedUserId)['name']} (${_messages.length})',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            if (_messages.isEmpty)
                              const Text('No messages found')
                            else
                              Column(
                                children: _messages.take(3).map((message) {
                                  return ListTile(
                                    leading: Icon(
                                      _getMessageIcon(message['type']),
                                      color: _getMessageColor(message['priority']),
                                    ),
                                    title: Text(message['title']),
                                    subtitle: Text(
                                      message['body'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: message['isRead']
                                        ? const Icon(Icons.mark_email_read, color: Colors.green)
                                        : const Icon(Icons.mark_email_unread, color: Colors.orange),
                                    onTap: () {
                                      _markMessageAsRead(message['id']);
                                    },
                                  );
                                }).toList(),
                              ),
                            if (_messages.length > 3)
                              TextButton(
                                onPressed: () {
                                  // Show all messages
                                },
                                child: Text('View all ${_messages.length} messages'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Attendance Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent Attendance (${_attendance.length})',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            if (_attendance.isEmpty)
                              const Text('No attendance records found')
                            else
                              Column(
                                children: _attendance.map((record) {
                                  return ListTile(
                                    leading: Icon(
                                      record['location'] == 'Remote' 
                                          ? Icons.home 
                                          : Icons.business,
                                      color: Colors.blue,
                                    ),
                                    title: Text(
                                      _formatDate(record['date']),
                                    ),
                                    subtitle: Text(
                                      '${_formatTime(record['checkIn'])} - ${_formatTime(record['checkOut'])} (${record['workingHours']}h)',
                                    ),
                                    trailing: Chip(
                                      label: Text(record['status'].toUpperCase()),
                                      backgroundColor: record['status'] == 'present' 
                                          ? Colors.green.shade100 
                                          : Colors.red.shade100,
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _addSampleAttendance,
                                icon: const Icon(Icons.add_circle),
                                label: const Text('Add Attendance'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _testConnection,
                                icon: const Icon(Icons.wifi_protected_setup),
                                label: const Text('Test Connection'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  IconData _getMessageIcon(String type) {
    switch (type) {
      case 'welcome':
        return Icons.waving_hand;
      case 'achievement':
        return Icons.celebration;
      case 'announcement':
        return Icons.campaign;
      case 'review':
        return Icons.rate_review;
      default:
        return Icons.message;
    }
  }

  Color _getMessageColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    DateTime time = timestamp.toDate();
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _markMessageAsRead(String messageId) async {
    bool success = await HRMDataService.markMessageAsRead(messageId);
    if (success) {
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m['id'] == messageId);
        if (messageIndex != -1) {
          _messages[messageIndex]['isRead'] = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message marked as read')),
      );
    }
  }

  Future<void> _addSampleAttendance() async {
    if (_selectedUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user first')),
      );
      return;
    }

    final user = _users.firstWhere((u) => u['id'] == _selectedUserId);
    DateTime now = DateTime.now();
    DateTime checkIn = DateTime(now.year, now.month, now.day, 9, 0);
    DateTime checkOut = DateTime(now.year, now.month, now.day, 17, 30);

    Map<String, dynamic> attendanceData = {
      'userId': _selectedUserId,
      'employeeId': user['employeeId'],
      'date': DateTime(now.year, now.month, now.day),
      'checkIn': checkIn,
      'checkOut': checkOut,
      'workingHours': 8.5,
      'status': 'present',
      'location': 'Office',
      'notes': 'Added via demo app',
      'breakTime': 1.0,
      'overtime': 0.5,
    };

    bool success = await HRMDataService.addAttendanceRecord(attendanceData);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance record added successfully')),
      );
      // Reload attendance data
      await _loadUserData(_selectedUserId);
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add attendance record')),
      );
    }
  }

  Future<void> _testConnection() async {
    bool isConnected = await HRMDataService.testConnection();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isConnected 
            ? 'Firestore connection successful!' 
            : 'Firestore connection failed!'),
        backgroundColor: isConnected ? Colors.green : Colors.red,
      ),
    );
  }
}