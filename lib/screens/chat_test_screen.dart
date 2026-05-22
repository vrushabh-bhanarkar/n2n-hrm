import 'package:flutter/material.dart';
import 'package:cnattendance/services/realtime_chat_service.dart';
import 'package:cnattendance/model/chat.dart';
import 'package:cnattendance/utils/constant.dart';

/// Simple chat test screen to verify Firebase Realtime Database messaging
class ChatTestScreen extends StatefulWidget {
  const ChatTestScreen({Key? key}) : super(key: key);

  @override
  State<ChatTestScreen> createState() => _ChatTestScreenState();
}

class _ChatTestScreenState extends State<ChatTestScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _conversationId = '3_5'; // Conversation between user 3 and 5
  List<Chat> _messages = [];
  bool _isLoading = false;
  bool _isDatabaseConnected = false;
  String _currentUserId = '5'; // Default to Atharva's ID

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    
    try {
      // Initialize Firebase Realtime Database
      await RealtimeChatService.initialize();
      
      // Check database connection
      bool isAvailable = await RealtimeChatService.isRealtimeDBAvailable();
      setState(() => _isDatabaseConnected = isAvailable);
      
      if (isAvailable) {
        // Initialize user profiles with your team data
        await _initializeUserProfiles();
        
        // Load existing messages
        await _loadMessages();
        
        // Listen for new messages
        _listenToMessages();
        
        _showSnackBar('✅ Connected to Firebase Realtime Database', Colors.green);
      } else {
        _showSnackBar('❌ Failed to connect to database', Colors.red);
      }
    } catch (e) {
      print('Error initializing chat: $e');
      _showSnackBar('❌ Error: $e', Colors.red);
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _initializeUserProfiles() async {
    try {
      // Initialize Atharva's profile
      await RealtimeChatService.initializeUserProfile(
        userId: 5,
        name: "Atharva Patil",
        email: "atharva@n2nsolution.co",
        username: "n2natharva",
        branch: "Pune",
        department: "Developers",
        post: "Flutter Developer",
        phone: "",
        avatar: "",
      );
      
      // Initialize Vrushabh's profile
      await RealtimeChatService.initializeUserProfile(
        userId: 3,
        name: "Vrushabh Bhanarkar",
        email: "vrushabh@n2nsolution.co",
        username: "n2nvrushabh",
        branch: "Pune",
        department: "Developers",
        post: "Flutter Developer",
        phone: "918446240546",
        avatar: "${Constant.MAIN_URL}/uploads/user/avatar/Thumb-68666ac9333cb_1000091256.png",
      );
      
      print('✅ User profiles initialized');
    } catch (e) {
      print('Error initializing user profiles: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      List<Chat> messages = await RealtimeChatService.getMessages(_conversationId);
      setState(() {
        _messages = messages;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  void _listenToMessages() {
    RealtimeChatService.getMessagesStream(_conversationId).listen(
      (List<Chat> messages) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      },
      onError: (error) {
        print('Error listening to messages: $error');
        _showSnackBar('❌ Connection error: $error', Colors.orange);
      },
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    String messageText = _messageController.text.trim();
    _messageController.clear();
    
    try {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      Chat message = Chat(
        'msg_${_currentUserId}_$timestamp',
        messageText,
        _currentUserId,
        _currentUserId == '5' ? '3' : '5', // Send to the other user
        DateTime.now(),
      );
      
      bool success = await RealtimeChatService.sendMessage(message);
      
      if (success) {
        _showSnackBar('✅ Message sent', Colors.green);
      } else {
        _showSnackBar('❌ Failed to send message', Colors.red);
      }
    } catch (e) {
      print('Error sending message: $e');
      _showSnackBar('❌ Error: $e', Colors.red);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Chat Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isDatabaseConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isDatabaseConnected ? Colors.green : Colors.red,
            ),
            onPressed: _initializeChat,
            tooltip: _isDatabaseConnected ? 'Connected' : 'Disconnected',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _currentUserId = value;
                _conversationId = value == '5' ? '3_5' : '3_5'; // Same conversation
              });
              _loadMessages();
              _showSnackBar('Switched to user $value', Colors.blue);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: '5',
                child: Text('Atharva (ID: 5)'),
              ),
              const PopupMenuItem(
                value: '3',
                child: Text('Vrushabh (ID: 3)'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('User $_currentUserId'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Connection status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  color: _isDatabaseConnected ? Colors.green.shade100 : Colors.red.shade100,
                  child: Text(
                    _isDatabaseConnected 
                        ? '🟢 Connected to Firebase Realtime Database'
                        : '🔴 Database connection failed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isDatabaseConnected ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // Messages list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      Chat message = _messages[index];
                      bool isMyMessage = message.sender == _currentUserId;
                      
                      return Align(
                        alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(12.0),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          decoration: BoxDecoration(
                            color: isMyMessage ? Colors.blue : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.message,
                                style: TextStyle(
                                  color: isMyMessage ? Colors.white : Colors.black87,
                                  fontSize: 16.0,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                '${message.dateTime.hour}:${message.dateTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: isMyMessage ? Colors.white70 : Colors.black54,
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Message input
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 4.0,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      FloatingActionButton.small(
                        onPressed: _sendMessage,
                        child: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}