class HRMDataService {
  static Future<bool> testConnection() async { return true; }
  static Future<List<Map<String, dynamic>>> getUsers() async { return []; }
  static Future<Map<String, dynamic>> getCompanySettings() async { return {}; }
  static Future<List<Map<String, dynamic>>> getMessagesForUser(int userId) async { return []; }
  static Future<List<Map<String, dynamic>>> getAllMessages() async { return []; }
  static Future<List<Map<String, dynamic>>> getAttendanceForUser(int userId, {int days = 7}) async { return []; }
  static Future<bool> markMessageAsRead(String messageId) async { return true; }
  static Future<bool> addAttendanceRecord(Map<String, dynamic> attendanceData) async { return true; }
  static Future<String?> addMessage(Map<String, dynamic> messageData) async { return 'mock_id'; }
  static Future<String?> addBroadcastMessage(Map<String, dynamic> messageData) async { return 'mock_id'; }
  static Future<bool> deleteMessage(String messageId) async { return true; }
  static Future<bool> archiveExpiredMessages() async { return true; }
}
