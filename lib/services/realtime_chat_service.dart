import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cnattendance/model/chat.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/firebase_options.dart';

/// Firebase Realtime Database service for real-time chat messaging
class RealtimeChatService {
  static FirebaseDatabase? _database;
  static final Preferences _pref = Preferences();
  
  // Initialize Firebase Realtime Database using the configured options
  static Future<void> initialize() async {
    try {
      // Ensure Firebase is initialized first
      if (Firebase.apps.isEmpty) {
        print('⚠️ Firebase not initialized, skipping Realtime Database initialization');
        return;
      }
      
      // Test if Firebase Database plugin is available
      try {
        final databaseURL = DefaultFirebaseOptions.currentPlatform.databaseURL;
        if (databaseURL == null || databaseURL.isEmpty) {
          print('⚠️ Firebase Realtime Database URL is not configured. Add databaseURL to firebase_options.dart and re-run flutterfire configure.');
          _database = null;
          return;
        }

        // Use the database URL from Firebase options
        _database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: databaseURL,
        );
        
        // Test connection with a simple operation
        await _database!.ref('.info/connected').once();
        
        // Enable offline persistence
        try {
          _database!.setPersistenceEnabled(true);
          _database!.setPersistenceCacheSizeBytes(10000000); // 10MB cache
        } catch (e) {
          print('⚠️ Failed to set persistence: $e');
        }
        
        print('✅ Firebase Realtime Database initialized with URL: ${DefaultFirebaseOptions.currentPlatform.databaseURL}');
      } catch (pluginError) {
        print('❌ Firebase Database plugin not available: $pluginError');
        _database = null;
        // Continue without Firebase Database - use local storage only
      }
    } catch (e) {
      print('❌ Failed to initialize Firebase Realtime Database: $e');
      _database = null;
    }
  }

  /// Send a message to Realtime Database
  static Future<bool> sendMessage(Chat message) async {
    try {
      if (_database == null) {
        await initialize();
        if (_database == null) {
          print('❌ Firebase Database not available');
          return false;
        }
      }

      String currentUserName = await _pref.getFullName();
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create conversation ID from sender and receiver IDs (sorted for consistency)
      List<String> participants = [message.sender, message.reciever];
      participants.sort();
      String conversationId = participants.join('_');
      
      // Create message data with enhanced structure
      Map<String, dynamic> messageData = {
        'id': message.id,
        'message': message.message,
        'senderId': message.sender,
        'receiverId': message.reciever,
        'senderName': currentUserName,
        'timestamp': ServerValue.timestamp,
        'clientTimestamp': int.parse(timestamp),
        'isRead': false,
        'messageType': 'text',
        'conversationId': conversationId,
        'createdAt': DateTime.now().toIso8601String(),
        'lastModified': ServerValue.timestamp,
      };

      // Save to conversations/{conversationId}/messages/{timestamp}
      DatabaseReference messageRef = _database!
          .ref('conversations')
          .child(conversationId)
          .child('messages')
          .child(timestamp);
      
      await messageRef.set(messageData);

      // Update conversation metadata
      await _updateConversationMetadata(conversationId, message, currentUserName, timestamp);

      // Update user's conversation list
      await _updateUserConversations(message.sender, conversationId, timestamp);
      await _updateUserConversations(message.reciever, conversationId, timestamp);

      print('✅ Message sent to Realtime Database: ${message.message}');
      return true;
    } catch (e) {
      print('❌ Failed to send message to Realtime Database: $e');
      return false;
    }
  }

  /// Send group message to Realtime Database
  static Future<bool> sendGroupMessage(
    String conversationId, 
    String message, 
    String sender, 
    String projectId, 
    List<String> participants
  ) async {
    try {
      if (_database == null) {
        await initialize();
      }

      String currentUserName = await _pref.getFullName();
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String messageId = '${conversationId}_$timestamp'; // Unique message ID
      
      Map<String, dynamic> messageData = {
        'id': messageId,
        'message': message,
        'sender': sender,
        'receiver': conversationId, // Group conversation ID as receiver
        'timestamp': ServerValue.timestamp,
        'clientTimestamp': timestamp,
        'senderName': currentUserName,
        'isRead': false,
        'messageType': 'text',
        'projectId': projectId,
        'isGroup': true,
        'participants': participants,
        'createdAt': DateTime.now().toIso8601String(),
      };

      DatabaseReference messagesRef = _database!
          .ref('messages')
          .child(conversationId)
          .child(timestamp);
      
      await messagesRef.set(messageData);

      // Update group conversation metadata
      await _updateGroupConversation(conversationId, message, sender, projectId, participants, timestamp);

      print('✅ Group message sent to Realtime Database');
      return true;
    } catch (e) {
      print('❌ Failed to send group message to Realtime Database: $e');
      return false;
    }
  }

  /// Listen to messages for a conversation in real-time
  static Stream<List<Chat>> getMessagesStream(String conversationId) {
    try {
      if (_database == null) {
        print('⚠️ Firebase Database not available, returning empty stream');
        return Stream.empty();
      }

      return _database!
          .ref('conversations')
          .child(conversationId)
          .child('messages')
          .orderByChild('clientTimestamp')
          .onValue
          .map((DatabaseEvent event) {
        List<Chat> messages = [];
        
        try {
          if (event.snapshot.value != null) {
            Map<dynamic, dynamic> messagesData = event.snapshot.value as Map<dynamic, dynamic>;
            
            messagesData.forEach((key, value) {
              try {
                Map<String, dynamic> messageMap = Map<String, dynamic>.from(value);
                
                Chat chat = Chat(
                  messageMap['id'] ?? '',
                  messageMap['message'] ?? '',
                  messageMap['senderId'] ?? messageMap['sender'] ?? '', // backward compatibility
                  messageMap['receiverId'] ?? messageMap['receiver'] ?? '', // backward compatibility
                  DateTime.fromMillisecondsSinceEpoch(
                    messageMap['clientTimestamp'] ?? 0
                  ),
                );
                
                messages.add(chat);
              } catch (e) {
                print('❌ Error parsing message: $e');
              }
            });
            
            // Sort messages by timestamp
            messages.sort((a, b) => a.dateTime.compareTo(b.dateTime));
          }
        } catch (e) {
          print('❌ Error processing messages data: $e');
        }
        
        print('📱 Loaded ${messages.length} messages for conversation $conversationId');
        return messages;
      }).handleError((error) {
        print('❌ Firebase Database stream error: $error');
        // Return empty list on error to prevent app crash
        return <Chat>[];
      });
    } catch (e) {
      print('❌ Error setting up messages stream: $e');
      // Return a stream that emits empty list and then completes
      return Stream.value(<Chat>[]);
    }
  }

  /// Get messages for a conversation (one-time fetch)
  static Future<List<Chat>> getMessages(String conversationId) async {
    try {
      if (_database == null) {
        await initialize();
      }

      DataSnapshot snapshot = await _database!
          .ref('conversations')
          .child(conversationId)
          .child('messages')
          .orderByChild('clientTimestamp')
          .get();

      List<Chat> messages = [];
      
      if (snapshot.value != null) {
        Map<dynamic, dynamic> messagesData = snapshot.value as Map<dynamic, dynamic>;
        
        messagesData.forEach((key, value) {
          Map<String, dynamic> messageMap = Map<String, dynamic>.from(value);
          
          Chat chat = Chat(
            messageMap['id'] ?? '',
            messageMap['message'] ?? '',
            messageMap['senderId'] ?? messageMap['sender'] ?? '', // backward compatibility
            messageMap['receiverId'] ?? messageMap['receiver'] ?? '', // backward compatibility
            DateTime.fromMillisecondsSinceEpoch(
              messageMap['clientTimestamp'] ?? 0
            ),
          );
          
          messages.add(chat);
        });
        
        // Sort messages by timestamp
        messages.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      }
      
      print('✅ Loaded ${messages.length} messages from Realtime Database');
      return messages;
    } catch (e) {
      print('❌ Failed to load messages from Realtime Database: $e');
      return [];
    }
  }

  /// Update group conversation metadata
  static Future<void> _updateGroupConversation(
    String conversationId, 
    String message, 
    String sender, 
    String projectId, 
    List<String> participants,
    String messageId
  ) async {
    try {
      Map<String, dynamic> conversationData = {
        'conversationId': conversationId,
        'lastMessage': message,
        'lastMessageTime': ServerValue.timestamp,
        'lastMessageId': messageId,
        'lastSender': sender,
        'participants': participants,
        'updatedAt': ServerValue.timestamp,
        'isGroup': true,
        'projectId': projectId,
      };

      await _database!
          .ref('conversations')
          .child(conversationId)
          .set(conversationData);

      print('✅ Group conversation updated in Realtime Database');
    } catch (e) {
      print('❌ Failed to update group conversation: $e');
    }
  }

  /// Mark messages as read
  static Future<void> markMessagesAsRead(String conversationId, String currentUser) async {
    try {
      if (_database == null) return;

      DataSnapshot snapshot = await _database!
          .ref('messages')
          .child(conversationId)
          .orderByChild('receiver')
          .equalTo(currentUser)
          .get();

      if (snapshot.value != null) {
        Map<dynamic, dynamic> messages = snapshot.value as Map<dynamic, dynamic>;
        
        Map<String, dynamic> updates = {};
        messages.forEach((key, value) {
          if (value['isRead'] == false) {
            updates['messages/$conversationId/$key/isRead'] = true;
          }
        });
        
        if (updates.isNotEmpty) {
          await _database!.ref().update(updates);
          print('✅ Messages marked as read');
        }
      }
    } catch (e) {
      print('❌ Failed to mark messages as read: $e');
    }
  }

  /// Get conversations for current user
  static Stream<List<Map<String, dynamic>>> getConversationsStream() async* {
    try {
      String currentUsername = await _pref.getUsername();
      
      if (_database == null) {
        yield [];
        return;
      }

      yield* _database!
          .ref('conversations')
          .orderByChild('lastMessageTime')
          .onValue
          .map((DatabaseEvent event) {
        List<Map<String, dynamic>> conversations = [];
        
        if (event.snapshot.value != null) {
          Map<dynamic, dynamic> conversationsData = event.snapshot.value as Map<dynamic, dynamic>;
          
          conversationsData.forEach((key, value) {
            Map<String, dynamic> conv = Map<String, dynamic>.from(value);
            
            // Filter conversations where current user is a participant
            List<dynamic> participants = conv['participants'] ?? [];
            if (participants.contains(currentUsername)) {
              conv['docId'] = key;
              conversations.add(conv);
            }
          });
          
          // Sort by last message time (newest first)
          conversations.sort((a, b) {
            int timeA = a['lastMessageTime'] ?? 0;
            int timeB = b['lastMessageTime'] ?? 0;
            return timeB.compareTo(timeA);
          });
        }
        
        return conversations;
      });
    } catch (e) {
      print('❌ Failed to get conversations stream: $e');
      yield [];
    }
  }

  /// Delete a conversation and all its messages
  static Future<bool> deleteConversation(String conversationId) async {
    try {
      if (_database == null) return false;

      Map<String, dynamic> updates = {
        'messages/$conversationId': null,
        'conversations/$conversationId': null,
      };
      
      await _database!.ref().update(updates);
      print('✅ Conversation deleted from Realtime Database');
      return true;
    } catch (e) {
      print('❌ Failed to delete conversation: $e');
      return false;
    }
  }

  /// Check if Realtime Database is available
  static Future<bool> isRealtimeDBAvailable() async {
    try {
      if (_database == null) {
        await initialize();
      }
      
      // Try to read from a test path
      await _database!.ref('.info/connected').get();
      return true;
    } catch (e) {
      print('❌ Realtime Database not available: $e');
      return false;
    }
  }

  /// Get online status
  static Stream<bool> getConnectionStatus() {
    if (_database == null) {
      return Stream.value(false);
    }
    
    return _database!
        .ref('.info/connected')
        .onValue
        .map((event) => event.snapshot.value == true);
  }

  /// Set user online status
  static Future<void> setUserOnlineStatus(bool isOnline) async {
    try {
      if (_database == null) {
        await initialize();
        if (_database == null) return;
      }

      final int currentUserId = await _pref.getUserId();
      final String currentUsername = await _pref.getUsername();

      // Presence records are keyed by user id. Fall back to username only when id is unavailable.
      final String userKey = currentUserId > 0
          ? currentUserId.toString()
          : currentUsername;

      if (userKey.isEmpty) {
        return;
      }

      await _database!
          .ref('users')
          .child(userKey)
          .update({
        'isOnline': isOnline,
        'lastSeen': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });
      
      print('✅ User online status updated: $isOnline');
    } catch (e) {
      print('❌ Failed to update online status: $e');
    }
  }

  /// Update conversation metadata
  static Future<void> _updateConversationMetadata(String conversationId, Chat message, String senderName, String timestamp) async {
    try {
      if (_database == null) return;

      Map<String, dynamic> conversationData = {
        'id': conversationId,
        'lastMessage': message.message,
        'lastMessageTime': ServerValue.timestamp,
        'lastMessageSender': message.sender,
        'lastMessageSenderName': senderName,
        'participants': [message.sender, message.reciever],
        'updatedAt': DateTime.now().toIso8601String(),
        'type': 'direct', // direct message
      };

      await _database!
          .ref('conversations')
          .child(conversationId)
          .child('metadata')
          .set(conversationData);

    } catch (e) {
      print('❌ Failed to update conversation metadata: $e');
    }
  }

  /// Update user's conversation list
  static Future<void> _updateUserConversations(String userId, String conversationId, String timestamp) async {
    try {
      if (_database == null) return;

      Map<String, dynamic> userConversationData = {
        'conversationId': conversationId,
        'lastActivity': ServerValue.timestamp,
        'unreadCount': 0, // Will be updated when messages are received
      };

      await _database!
          .ref('users')
          .child(userId)
          .child('conversations')
          .child(conversationId)
          .set(userConversationData);

    } catch (e) {
      print('❌ Failed to update user conversations: $e');
    }
  }

  /// Initialize user profile in the database (call this after login)
  static Future<void> initializeUserProfile({
    required int userId,
    required String name,
    required String email,
    required String username,
    required String branch,
    required String department,
    String? avatar,
    String? post,
    String? phone,
  }) async {
    try {
      if (_database == null) {
        await initialize();
        if (_database == null) return;
      }

      Map<String, dynamic> userProfile = {
        'id': userId,
        'name': name,
        'email': email,
        'username': username,
        'branch': branch,
        'department': department,
        'avatar': avatar ?? '',
        'post': post ?? '',
        'phone': phone ?? '',
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': ServerValue.timestamp,
      };

      await _database!
          .ref('users')
          .child(userId.toString())
          .set(userProfile);

      print('✅ User profile initialized in Realtime Database: $name');
    } catch (e) {
      print('❌ Failed to initialize user profile: $e');
    }
  }

  /// Get user profile from database
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      if (_database == null) return null;

      DataSnapshot snapshot = await _database!
          .ref('users')
          .child(userId)
          .get();

      if (snapshot.value != null) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('❌ Failed to get user profile: $e');
      return null;
    }
  }

  /// Get team members for a department/branch
  static Future<List<Map<String, dynamic>>> getTeamMembers({String? department, String? branch}) async {
    try {
      if (_database == null) return [];

      Query query = _database!.ref('users');
      
      // If department is specified, filter by department
      if (department != null) {
        query = query.orderByChild('department').equalTo(department);
      } else if (branch != null) {
        query = query.orderByChild('branch').equalTo(branch);
      }

      DataSnapshot snapshot = await query.get();
      List<Map<String, dynamic>> teamMembers = [];

      if (snapshot.value != null) {
        Map<dynamic, dynamic> users = snapshot.value as Map<dynamic, dynamic>;
        users.forEach((key, value) {
          Map<String, dynamic> user = Map<String, dynamic>.from(value);
          user['userId'] = key;
          teamMembers.add(user);
        });
      }

      print('✅ Loaded ${teamMembers.length} team members');
      return teamMembers;
    } catch (e) {
      print('❌ Failed to load team members: $e');
      return [];
    }
  }
}