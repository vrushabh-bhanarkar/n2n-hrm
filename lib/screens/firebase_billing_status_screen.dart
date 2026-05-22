import 'package:flutter/material.dart';
import 'package:cnattendance/services/hrm_data_service.dart';
import 'package:url_launcher/url_launcher.dart';

class FirebaseBillingStatusScreen extends StatefulWidget {
  const FirebaseBillingStatusScreen({Key? key}) : super(key: key);

  @override
  State<FirebaseBillingStatusScreen> createState() => _FirebaseBillingStatusScreenState();
}

class _FirebaseBillingStatusScreenState extends State<FirebaseBillingStatusScreen> {
  bool _isChecking = false;
  String _status = 'Ready to check Firebase billing status';
  List<String> _logs = [];
  bool _billingRequired = false;
  String _projectId = 'sod-hrm';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Billing Status'),
        backgroundColor: _billingRequired ? Colors.red : Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: _billingRequired ? Colors.red.shade50 : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _billingRequired ? Icons.error : Icons.info,
                          color: _billingRequired ? Colors.red : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _status,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _billingRequired ? Colors.red : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_billingRequired) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '🚨 Action Required: Firebase billing must be enabled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isChecking ? null : _checkBillingStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Status'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                if (_billingRequired) ...[
                  ElevatedButton.icon(
                    onPressed: _openBillingConsole,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Enable Billing'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openFirebaseConsole,
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Firebase Console'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                ],
                ElevatedButton.icon(
                  onPressed: _testMessageCreation,
                  icon: const Icon(Icons.message),
                  label: const Text('Test Messages'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _billingRequired ? Colors.grey : Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firebase Project Information',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Project ID', _projectId),
                    _buildInfoRow('Database', 'Firestore'),
                    _buildInfoRow('Region', 'us-central1 (default)'),
                    _buildInfoRow('Plan', 'Spark (Pay-as-you-go)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Solution Steps Card
            if (_billingRequired)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔧 How to Fix This Issue',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStep('1', 'Go to Google Cloud Console', 'Enable billing for project $_projectId'),
                      _buildStep('2', 'Link Billing Account', 'Create or select existing billing account'),
                      _buildStep('3', 'Wait for Propagation', 'Allow 2-5 minutes for changes to take effect'),
                      _buildStep('4', 'Test Again', 'Come back and test the connection'),
                      const SizedBox(height: 12),
                      const Text(
                        '💰 Don\'t worry: Firebase has generous free tiers. You likely won\'t be charged for development usage.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Logs Section
            if (_logs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Diagnostic Logs',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _logs.clear()),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _logs.join('\n'),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_isChecking)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.green,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkBillingStatus() async {
    setState(() {
      _isChecking = true;
      _logs.clear();
      _billingRequired = false;
    });

    _addLog('🔍 Checking Firebase Firestore connection...');
    _addLog('📋 Project ID: $_projectId');

    try {
      bool connectionSuccess = await HRMDataService.testConnection();
      
      if (connectionSuccess) {
        _addLog('✅ Connection successful - Billing is enabled!');
        setState(() {
          _status = 'Firebase billing is properly configured';
          _billingRequired = false;
        });
      } else {
        _addLog('❌ Connection failed - Billing issue detected');
        setState(() {
          _status = 'Firebase billing needs to be enabled';
          _billingRequired = true;
        });
      }
    } catch (e) {
      _addLog('❌ Error during connection test: $e');
      setState(() {
        _status = 'Connection test failed';
        _billingRequired = true;
      });
    }

    setState(() {
      _isChecking = false;
    });
  }

  Future<void> _testMessageCreation() async {
    if (_billingRequired) {
      _showBillingRequiredDialog();
      return;
    }

    setState(() {
      _isChecking = true;
    });

    _addLog('📧 Testing message creation...');

    try {
      String? messageId = await HRMDataService.addMessage({
        'title': 'Billing Test Message',
        'content': 'This message was created to test that billing is working correctly.',
        'sender': 'billing_test',
        'recipients': ['test_user'],
        'type': 'test',
        'priority': 'normal',
        'metadata': {'test': true, 'timestamp': DateTime.now().toString()},
      });

      if (messageId != null) {
        _addLog('✅ Message created successfully: $messageId');
        _addLog('🎉 Billing is working correctly!');
      } else {
        _addLog('❌ Message creation failed');
      }
    } catch (e) {
      _addLog('❌ Message creation error: $e');
      if (e.toString().contains('BILLING_REQUIRED')) {
        setState(() {
          _billingRequired = true;
          _status = 'Billing required for message operations';
        });
      }
    }

    setState(() {
      _isChecking = false;
    });
  }

  Future<void> _openBillingConsole() async {
    final Uri url = Uri.parse('https://console.developers.google.com/billing/enable?project=$_projectId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openFirebaseConsole() async {
    final Uri url = Uri.parse('https://console.firebase.google.com/project/$_projectId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showBillingRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Billing Required'),
        content: const Text(
          'Firebase billing must be enabled before you can test message creation.\n\n'
          'Please enable billing first, then try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openBillingConsole();
            },
            child: const Text('Enable Billing'),
          ),
        ],
      ),
    );
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
  }
}