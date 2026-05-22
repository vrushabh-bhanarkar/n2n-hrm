import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cnattendance/services/logout_status_service.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';

class LogoutPendingScreen extends StatefulWidget {
  final String? logoutId;
  final String message;

  const LogoutPendingScreen({
    Key? key,
    this.logoutId,
    this.message = 'Your logout request is pending admin approval',
  }) : super(key: key);

  @override
  State<LogoutPendingScreen> createState() => _LogoutPendingScreenState();
}

class _LogoutPendingScreenState extends State<LogoutPendingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _pollingTimer;
  bool _isChecking = false;
  bool _isApproved = false;
  bool _isRejected = false;
  String _statusMessage = 'Your logout request is pending admin approval.';
  StreamSubscription<RemoteMessage>? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _listenFCM();
    _startPollingBackup();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pollingTimer?.cancel();
    _fcmSubscription?.cancel();
    super.dispose();
  }

  void _listenFCM() {
    // Listen directly to FirebaseMessaging foreground stream for simplicity.
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final type = msg.data['type'];
      if (type == 'logout_approved') {
        _handleApproved(msg.data);
      } else if (type == 'logout_rejected') {
        _handleRejected(msg.data);
      }
    });
  }

  void _startPollingBackup() {
    // Poll every 15 seconds per spec
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_isApproved || _isRejected) return; // Stop if already resolved
      await _pollStatus();
    });
  }

  Future<void> _pollStatus() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      final result = await LogoutStatusService.checkLogoutApprovalStatus();
      final data = result?['data'];
      if (data != null) {
        final action = data['action'];
        if (action == 'logout_now') {
          _handleApproved(Map<String, dynamic>.from(data));
        } else if (action == 'rejected') {
          _handleRejected(Map<String, dynamic>.from(data));
        }
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _handleApproved(Map<String, dynamic> data) {
    if (_isApproved || _isRejected) return;
    setState(() {
      _isApproved = true;
      _statusMessage = 'Your logout request has been approved. Logging out...';
    });
    _pollingTimer?.cancel();
    // Shorten delay to avoid keeping the user waiting unnecessarily
    Future.delayed(const Duration(milliseconds: 500), _performLogout);
  }

  void _handleRejected(Map<String, dynamic> data) {
    if (_isApproved || _isRejected) return;
    setState(() {
      _isRejected = true;
      _statusMessage = 'Your logout request has been rejected. Returning home...';
    });
    _pollingTimer?.cancel();
    // Pop back to dashboard promptly
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      // Simply pop this screen to go back to dashboard
      Navigator.of(context).pop();
    });
  }

  Future<void> _performLogout() async {
    try {
      // Clear local session data
      await Preferences().clearPrefs();
    } catch (e) {
      debugPrint('Error clearing prefs during logout approval: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(initial: false)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Minimal, working UI returned from build to satisfy non-nullable return type.
    // You can restore the original styled layout later if needed.
    return WillPopScope(
      // Prevent back button - user must wait for approval
      onWillPop: () async => false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RotationTransition(
                    turns: _animationController,
                    child: Icon(
                      Icons.hourglass_empty,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isApproved
                        ? 'Logout Approved'
                        : _isRejected
                            ? 'Logout Rejected'
                            : 'Logout Pending',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                  ),
                  if (widget.logoutId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Request ID: ${widget.logoutId}',
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!_isApproved && !_isRejected)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(_isChecking ? 'Checking status...' : 'Waiting for approval...'),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
