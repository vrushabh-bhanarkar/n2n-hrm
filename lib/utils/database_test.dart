import 'package:cnattendance/services/realtime_chat_service.dart';
import 'package:cnattendance/model/chat.dart';
import 'package:cnattendance/utils/constant.dart';

/// Test Firebase Realtime Database connection and messaging functionality
class DatabaseTest {
  
  /// Test database connection
  static Future<bool> testConnection() async {
    try {
      print('🔄 Testing Firebase Realtime Database connection...');
      
      // Initialize the service
      await RealtimeChatService.initialize();
      
      // Check if database is available
      bool isAvailable = await RealtimeChatService.isRealtimeDBAvailable();
      
      if (isAvailable) {
        print('✅ Firebase Realtime Database connection successful!');
        return true;
      } else {
        print('❌ Firebase Realtime Database connection failed');
        return false;
      }
    } catch (e) {
      print('❌ Database connection test failed: $e');
      return false;
    }
  }
  
  /// Test user profile creation with your team data
  static Future<void> testUserProfileCreation() async {
    try {
      print('🔄 Testing user profile creation...');
      
      // Test with Atharva's data from your log
      await RealtimeChatService.initializeUserProfile(
        userId: 5,
        name: "Atharva Patil",
        email: "atharva@n2nsolution.co",
        username: "n2natharva",
        branch: "Pune",
        department: "Developers",
        post: "Flutter Developer",
      );
      
      // Test with Vrushabh's data
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
      
      print('✅ User profiles created successfully!');
    } catch (e) {
      print('❌ User profile creation failed: $e');
    }
  }
  
  /// Test sending a message
  static Future<void> testSendMessage() async {
    try {
      print('🔄 Testing message sending...');
      
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      Chat testMessage = Chat(
        'test_$timestamp',
        'Hello from Firebase Realtime Database! 🚀',
        '5', // Atharva's ID
        '3', // Vrushabh's ID
        DateTime.now(),
      );
      
      bool success = await RealtimeChatService.sendMessage(testMessage);
      
      if (success) {
        print('✅ Test message sent successfully!');
      } else {
        print('❌ Failed to send test message');
      }
    } catch (e) {
      print('❌ Message sending test failed: $e');
    }
  }
  
  /// Test retrieving messages
  static Future<void> testGetMessages() async {
    try {
      print('🔄 Testing message retrieval...');
      
      // Create conversation ID for Atharva (5) and Vrushabh (3)
      String conversationId = '3_5'; // Sorted IDs
      
      List<Chat> messages = await RealtimeChatService.getMessages(conversationId);
      
      print('✅ Retrieved ${messages.length} messages from database');
      
      for (Chat message in messages) {
        print('📱 Message: ${message.message} from ${message.sender} at ${message.dateTime}');
      }
    } catch (e) {
      print('❌ Message retrieval test failed: $e');
    }
  }
  
  /// Test getting team members
  static Future<void> testGetTeamMembers() async {
    try {
      print('🔄 Testing team members retrieval...');
      
      List<Map<String, dynamic>> devTeam = await RealtimeChatService.getTeamMembers(
        department: "Developers"
      );
      
      print('✅ Found ${devTeam.length} developers');
      
      for (var member in devTeam) {
        print('👤 ${member['name']} - ${member['post']} (${member['email']})');
      }
    } catch (e) {
      print('❌ Team members test failed: $e');
    }
  }
  
  /// Run all tests
  static Future<void> runAllTests() async {
    print('🧪 Starting Firebase Realtime Database Tests...\n');
    
    // Test 1: Connection
    bool connected = await testConnection();
    if (!connected) {
      print('❌ Stopping tests - no database connection');
      return;
    }
    
    print('\n' + '='*50 + '\n');
    
    // Test 2: User profiles
    await testUserProfileCreation();
    
    print('\n' + '='*50 + '\n');
    
    // Test 3: Send message
    await testSendMessage();
    
    print('\n' + '='*50 + '\n');
    
    // Test 4: Get messages
    await testGetMessages();
    
    print('\n' + '='*50 + '\n');
    
    // Test 5: Team members
    await testGetTeamMembers();
    
    print('\n🎉 All tests completed!');
  }
}