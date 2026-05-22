import 'package:flutter/material.dart';
import 'package:cnattendance/utils/api_logger.dart';

/// Quick test widget to verify API logging is working
/// Add this to your debug menu or testing screen
class ApiLoggerTestWidget extends StatelessWidget {
  const ApiLoggerTestWidget({Key? key}) : super(key: key);

  void _testApiLogger() {
    // Test 1: Log a sample request
    ApiLogger.logRequest(
      method: 'POST',
      url: 'https://api.example.com/attendance',
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.token',
      },
      body: {
        'type': 'checkIn',
        'note': 'Morning attendance',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // Test 2: Log a sample successful response
    ApiLogger.logResponse(
      method: 'POST',
      url: 'https://api.example.com/attendance',
      statusCode: 200,
      responseBody: '''
{
  "status": true,
  "message": "Attendance recorded successfully",
  "status_code": 200,
  "data": {
    "check_in_at": "2025-10-25 09:00:00",
    "check_out_at": null,
    "productive_time_in_min": 0
  }
}
''',
    );

    // Test 3: Log a sample error response
    ApiLogger.logResponse(
      method: 'POST',
      url: 'https://api.example.com/leave/apply',
      statusCode: 400,
      responseBody: '''
{
  "status": false,
  "message": "Invalid leave dates",
  "status_code": 400
}
''',
    );

    // Test 4: Log an error
    ApiLogger.logError(
      method: 'GET',
      url: 'https://api.example.com/profile',
      error: 'Connection timeout',
    );

    ApiLogger.log('API Logger test completed! Check debug console.',
        emoji: '✅');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API Logger Test',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Test the centralized API logging system',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _testApiLogger,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run Test'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    ApiLogger.clearConsole();
                    ApiLogger.log('Console cleared!', emoji: '🧹');
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Console'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ApiLogger.setEnabled(false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API Logging disabled')),
                    );
                  },
                  icon: const Icon(Icons.visibility_off),
                  label: const Text('Disable Logging'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    ApiLogger.setEnabled(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API Logging enabled')),
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Enable Logging'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
