import 'dart:convert';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/wifi_polling_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WiFi Attendance Provider for tracking break times and attendance status
/// 
/// Maintains:
/// - Current session status (checked_in, on_break, checked_out)
/// - Break log with disconnect/reconnect events
/// - Total break time accumulated
/// - First check-in and last check-out times

class WifiAttendanceProvider with ChangeNotifier {
  final SharedPreferences preferences;

  bool _enabled = false;
  String _officeBssid = '';
  String _officeSsid = '';
  String _sessionStatus = 'none';
  String _firstCheckinTime = '';
  String _lastCheckoutTime = '';
  int _totalBreakMinutes = 0;
  List<Map<String, dynamic>> _breakLog = [];
  String _currentBreakStart = '';
  DateTime? _lastDisconnectTime;

  bool get enabled => _enabled;
  String get officeBssid => _officeBssid;
  String get officeSsid => _officeSsid;
  String get sessionStatus => _sessionStatus;
  String get firstCheckinTime => _firstCheckinTime;
  String get lastCheckoutTime => _lastCheckoutTime;
  int get totalBreakMinutes => _totalBreakMinutes;
  List<Map<String, dynamic>> get breakLog => _breakLog;
  String get currentBreakStart => _currentBreakStart;
  int get breakCount => _breakLog.length;

  /// Formatted total break time (e.g., "1h 30m")
  String get formattedTotalBreakTime {
    if (_totalBreakMinutes == 0) return '0m';
    final hours = _totalBreakMinutes ~/ 60;
    final mins = _totalBreakMinutes % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  /// Human-readable session status
  String get sessionStatusLabel {
    switch (_sessionStatus) {
      case 'checked_in':
        return '🟢 Checked In';
      case 'on_break':
        return '🟡 On Break';
      case 'checked_out':
        return '🔴 Checked Out';
      default:
        return '⚪ None';
    }
  }

  /// Is currently on break
  bool get isOnBreak => _sessionStatus == 'on_break';

  /// Is currently checked in (including break time)
  bool get isCheckedIn =>
      _sessionStatus == 'checked_in' || _sessionStatus == 'on_break';

  WifiAttendanceProvider({required this.preferences}) {
    _init();
  }

  void _init() {
    loadData();
  }

  /// Load all data from SharedPreferences
  Future<void> loadData() async {
    try {
      _enabled = preferences.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;
      _officeBssid = preferences.getString(Preferences.WIFI_OFFICE_BSSID) ?? '';
      _officeSsid = preferences.getString(Preferences.WIFI_OFFICE_SSID) ?? '';
      _sessionStatus =
          preferences.getString(Preferences.WIFI_SESSION_STATUS) ?? 'none';
      _firstCheckinTime =
          preferences.getString(Preferences.WIFI_FIRST_CHECKIN_TIME) ?? '';
      _lastCheckoutTime =
          preferences.getString(Preferences.WIFI_LAST_CHECKOUT_TIME) ?? '';
      _totalBreakMinutes =
          preferences.getInt(Preferences.WIFI_TOTAL_BREAK_MINUTES) ?? 0;
      _currentBreakStart =
          preferences.getString(Preferences.WIFI_BREAK_START_TIME) ?? '';

      // Load break log
      final logJson = preferences.getString(Preferences.WIFI_BREAK_LOG) ?? '[]';
      try {
        final decoded = jsonDecode(logJson) as List<dynamic>;
        _breakLog = decoded.cast<Map<String, dynamic>>();
      } catch (_) {
        _breakLog = [];
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading WiFi attendance data: $e');
    }
  }

  /// Set WiFi auto-attendance enabled/disabled
  Future<void> setEnabled(bool value) async {
    try {
      _enabled = value;
      await preferences.setBool(Preferences.WIFI_AUTO_ENABLED, value);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error setting WiFi auto-attendance: $e');
    }
  }

  /// Set office WiFi BSSID (MAC address)
  Future<void> setOfficeBssid(String bssid) async {
    try {
      _officeBssid = bssid;
      await preferences.setString(Preferences.WIFI_OFFICE_BSSID, bssid);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error setting office BSSID: $e');
    }
  }

  /// Set office WiFi SSID (network name)
  Future<void> setOfficeSsid(String ssid) async {
    try {
      _officeSsid = ssid;
      await preferences.setString(Preferences.WIFI_OFFICE_SSID, ssid);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error setting office SSID: $e');
    }
  }

  /// Update session status
  Future<void> updateSessionStatus(String status) async {
    try {
      final previousStatus = _sessionStatus;
      _sessionStatus = status;

      await preferences.setString(Preferences.WIFI_SESSION_STATUS, status);

      // Track status changes
      if (previousStatus != status) {
        _trackStatusChange(previousStatus, status);
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error updating session status: $e');
    }
  }

  /// Record check-in time
  Future<void> recordCheckIn() async {
    try {
      final now = DateTime.now().toIso8601String();
      _firstCheckinTime = now;
      _sessionStatus = 'checked_in';
      _totalBreakMinutes = 0;
      _breakLog.clear();
      _currentBreakStart = '';

      await preferences.setString(Preferences.WIFI_FIRST_CHECKIN_TIME, now);
      await preferences.setString(Preferences.WIFI_SESSION_STATUS, 'checked_in');
      await preferences.setInt(Preferences.WIFI_TOTAL_BREAK_MINUTES, 0);
      await preferences.setString(Preferences.WIFI_BREAK_LOG, jsonEncode([]));

      _addBreakLogEntry('checked_in', now);

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error recording check-in: $e');
    }
  }

  /// Record check-out time
  Future<void> recordCheckOut() async {
    try {
      final now = DateTime.now().toIso8601String();
      _lastCheckoutTime = now;
      _sessionStatus = 'checked_out';
      _currentBreakStart = '';

      await preferences.setString(Preferences.WIFI_LAST_CHECKOUT_TIME, now);
      await preferences.setString(Preferences.WIFI_SESSION_STATUS, 'checked_out');
      await preferences.setString(Preferences.WIFI_BREAK_START_TIME, '');

      _addBreakLogEntry('checked_out', now);

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error recording check-out: $e');
    }
  }

  /// Record WiFi disconnect
  Future<void> recordDisconnect() async {
    try {
      final now = DateTime.now();
      _lastDisconnectTime = now;

      if (_sessionStatus == 'checked_in') {
        _sessionStatus = 'on_break';
        _currentBreakStart = now.toIso8601String();

        await preferences.setString(
          Preferences.WIFI_SESSION_STATUS,
          'on_break',
        );
        await preferences.setString(
          Preferences.WIFI_BREAK_START_TIME,
          _currentBreakStart,
        );

        _addBreakLogEntry('disconnect', _currentBreakStart);

        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error recording disconnect: $e');
    }
  }

  /// Record WiFi reconnect
  Future<void> recordReconnect() async {
    try {
      final now = DateTime.now().toIso8601String();

      if (_sessionStatus == 'on_break' && _currentBreakStart.isNotEmpty) {
        // Calculate break duration
        try {
          final startTime = DateTime.parse(_currentBreakStart);
          final endTime = DateTime.parse(now);
          final breakMinutes = endTime.difference(startTime).inMinutes;

          _totalBreakMinutes += breakMinutes;

          await preferences.setInt(
            Preferences.WIFI_TOTAL_BREAK_MINUTES,
            _totalBreakMinutes,
          );
          await preferences.setString(Preferences.WIFI_BREAK_START_TIME, '');
        } catch (e) {
          if (kDebugMode) print('Error calculating break duration: $e');
        }

        _sessionStatus = 'checked_in';
        await preferences.setString(
          Preferences.WIFI_SESSION_STATUS,
          'checked_in',
        );
        _currentBreakStart = '';

        _addBreakLogEntry('reconnect', now);

        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error recording reconnect: $e');
    }
  }

  /// Add entry to break log
  void _addBreakLogEntry(String event, String timestamp) {
    try {
      _breakLog.add({
        'event': event,
        'timestamp': timestamp,
      });

      // Save to preferences
      preferences.setString(
        Preferences.WIFI_BREAK_LOG,
        jsonEncode(_breakLog),
      );
    } catch (e) {
      if (kDebugMode) print('Error adding break log entry: $e');
    }
  }

  /// Track status change for analytics
  void _trackStatusChange(String from, String to) {
    final timestamp = DateTime.now().toIso8601String();
    _addBreakLogEntry('status_change_${from}_to_$to', timestamp);
  }

  /// Reset today's break tracking
  Future<void> resetDailyBreakTracking() async {
    try {
      _totalBreakMinutes = 0;
      _breakLog.clear();
      _currentBreakStart = '';
      _sessionStatus = 'none';

      await preferences.setInt(Preferences.WIFI_TOTAL_BREAK_MINUTES, 0);
      await preferences.setString(Preferences.WIFI_BREAK_LOG, '[]');
      await preferences.setString(Preferences.WIFI_BREAK_START_TIME, '');
      await preferences.setString(Preferences.WIFI_SESSION_STATUS, 'none');

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error resetting daily break tracking: $e');
    }
  }

  /// Get break log as a readable list
  List<String> getReadableBreakLog() {
    return _breakLog.map((entry) {
      final event = entry['event'] ?? 'unknown';
      final timestamp = entry['timestamp'] ?? 'N/A';
      try {
        final dt = DateTime.parse(timestamp);
        final formatted =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        return '$event at $formatted';
      } catch (_) {
        return '$event at $timestamp';
      }
    }).toList();
  }

  /// Export session data as JSON
  Map<String, dynamic> exportSessionData() {
    return {
      'enabled': _enabled,
      'session_status': _sessionStatus,
      'first_checkin_time': _firstCheckinTime,
      'last_checkout_time': _lastCheckoutTime,
      'total_break_minutes': _totalBreakMinutes,
      'break_count': _breakLog.length,
      'office_bssid': _officeBssid,
      'office_ssid': _officeSsid,
      'break_log': _breakLog,
    };
  }

  @override
  void dispose() {
    super.dispose();
  }
}
