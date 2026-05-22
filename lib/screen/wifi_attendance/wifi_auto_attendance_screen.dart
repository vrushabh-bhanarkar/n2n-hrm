// import 'dart:async';
// import 'dart:convert';
// import 'dart:developer';
// import 'dart:io';

// import 'package:cnattendance/data/source/datastore/preferences.dart';
// import 'package:cnattendance/services/wifi_attendance_service.dart';
// import 'package:cnattendance/widget/radialDecoration.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_easyloading/flutter_easyloading.dart';
// import 'package:hexcolor/hexcolor.dart';
// import 'package:permission_handler/permission_handler.dart';

// class WifiAutoAttendanceScreen extends StatefulWidget {
//   const WifiAutoAttendanceScreen({super.key});

//   @override
//   State<WifiAutoAttendanceScreen> createState() =>
//       _WifiAutoAttendanceScreenState();
// }

// class _WifiAutoAttendanceScreenState extends State<WifiAutoAttendanceScreen> {
//   final Preferences _prefs = Preferences();

//   bool _enabled = false;
//   String _officeBssid = '';
//   String _officeSsid = '';
//   String _sessionStatus = 'none';
//   List<dynamic> _serverSsids = [];

//   // Check-in window
//   TimeOfDay _checkinStart = const TimeOfDay(hour: 8, minute: 0);
//   TimeOfDay _checkinEnd = const TimeOfDay(hour: 11, minute: 0);

//   // Check-out window
//   TimeOfDay _checkoutStart = const TimeOfDay(hour: 16, minute: 0);
//   TimeOfDay _checkoutEnd = const TimeOfDay(hour: 21, minute: 0);

//   // Break tracking
//   String _firstCheckinTime = '';
//   String _lastCheckoutTime = '';
//   int _totalBreakMinutes = 0;
//   List<Map<String, dynamic>> _breakLog = [];
//   String _currentBreakStart = '';

//   bool _loading = true;
//   Timer? _refreshTimer;

//   @override
//   void initState() {
//     super.initState();
//     _loadSettings();
//     // Refresh every 30 seconds to keep the dashboard updated
//     _refreshTimer = Timer.periodic(
//       const Duration(seconds: 30),
//       (_) => _refreshDashboard(),
//     );
//     // Listen for background service updates
//     WifiAttendanceService.addStatusListener(_onBackgroundUpdate);
//   }

//   @override
//   void dispose() {
//     _refreshTimer?.cancel();
//     WifiAttendanceService.removeStatusListener(_onBackgroundUpdate);
//     super.dispose();
//   }

//   void _onBackgroundUpdate() {
//     if (mounted) _refreshDashboard();
//   }

//   Future<void> _refreshDashboard() async {
//     final status = await _prefs.getWifiSessionStatus();
//     final firstCheckin = await _prefs.getWifiFirstCheckinTime();
//     final lastCheckout = await _prefs.getWifiLastCheckoutTime();
//     final totalBreak = await _prefs.getWifiTotalBreakMinutes();
//     final breakStartTime = await _prefs.getWifiBreakStartTime();
//     final logJson = await _prefs.getWifiBreakLog();

//     List<Map<String, dynamic>> breakLog = [];
//     try {
//       final decoded = jsonDecode(logJson) as List<dynamic>;
//       breakLog = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
//     } catch (_) {}

//     if (mounted) {
//       setState(() {
//         _sessionStatus = status;
//         _firstCheckinTime = firstCheckin;
//         _lastCheckoutTime = lastCheckout;
//         _totalBreakMinutes = totalBreak;
//         _breakLog = breakLog;
//         _currentBreakStart = breakStartTime;
//       });
//     }
//   }

//   Future<void> _loadSettings() async {
//     final enabled = await _prefs.getWifiAutoEnabled();
//     final bssid = await _prefs.getWifiOfficeBssid();
//     final ssid = await _prefs.getWifiOfficeSsid();
//     final checkin = await _prefs.getWifiCheckinWindow();
//     final checkout = await _prefs.getWifiCheckoutWindow();
//     final status = await _prefs.getWifiSessionStatus();
//     final firstCheckin = await _prefs.getWifiFirstCheckinTime();
//     final lastCheckout = await _prefs.getWifiLastCheckoutTime();
//     final totalBreak = await _prefs.getWifiTotalBreakMinutes();
//     final breakStartTime = await _prefs.getWifiBreakStartTime();
//     final logJson = await _prefs.getWifiBreakLog();
//     final serverSsidsJson = await _prefs.getWifiServerSsids();

//     List<dynamic> serverSsids = [];
//     try {
//       serverSsids = jsonDecode(serverSsidsJson);
//     } catch (_) {}

//     List<Map<String, dynamic>> breakLog = [];
//     try {
//       final decoded = jsonDecode(logJson) as List<dynamic>;
//       breakLog = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
//     } catch (_) {}

//     if (mounted) {
//       setState(() {
//         _enabled = enabled;
//         _officeBssid = bssid;
//         _officeSsid = ssid;
//         _checkinStart =
//             TimeOfDay(hour: checkin['startHour']!, minute: checkin['startMin']!);
//         _checkinEnd =
//             TimeOfDay(hour: checkin['endHour']!, minute: checkin['endMin']!);
//         _checkoutStart = TimeOfDay(
//             hour: checkout['startHour']!, minute: checkout['startMin']!);
//         _checkoutEnd =
//             TimeOfDay(hour: checkout['endHour']!, minute: checkout['endMin']!);
//         _sessionStatus = status;
//         _firstCheckinTime = firstCheckin;
//         _lastCheckoutTime = lastCheckout;
//         _totalBreakMinutes = totalBreak;
//         _breakLog = breakLog;
//         _currentBreakStart = breakStartTime;
//         _serverSsids = serverSsids;
//         _loading = false;
//       });
//     }
//   }

//   Future<void> _syncServerSsids() async {
//     EasyLoading.show(status: 'Fetching office WiFi list…');
//     try {
//       final ssids = await WifiAttendanceService.fetchAndCacheServerSsids();
//       EasyLoading.dismiss();
//       if (ssids.isEmpty) {
//         _showSnack('No office WiFi networks found from server.');
//         return;
//       }
//       if (mounted) {
//         setState(() {
//           _serverSsids = ssids;
//         });
//         _showSnack('Synced ${ssids.length} office WiFi network(s) from server.');
//       }
//     } catch (e) {
//       EasyLoading.dismiss();
//       _showSnack('Error fetching WiFi list: $e');
//       log('[WiFiAutoAttendance] syncServerSsids error: $e');
//     }
//   }

//   Future<void> _toggleEnabled(bool value) async {
//     if (value && _serverSsids.isEmpty && _officeBssid.isEmpty) {
//       _showSnack(
//           'Please sync office WiFi first by tapping "Sync Office WiFi".');
//       return;
//     }
//     if (value) {
//       final granted = await _requestRequiredPermissions();
//       if (!granted) return;
//     }
//     await _prefs.saveWifiAutoEnabled(value);
//     setState(() => _enabled = value);
//     await WifiAttendanceService.reconfigure(enabled: value);
//     _showSnack(value
//         ? 'Auto WiFi attendance enabled ✅'
//         : 'Auto WiFi attendance disabled');
//   }

//   Future<void> _pickTime(TimeOfDay initial, String label,
//       void Function(TimeOfDay) onPicked) async {
//     final picked = await showTimePicker(
//       context: context,
//       initialTime: initial,
//       helpText: label,
//       builder: (context, child) => Theme(
//         data: Theme.of(context).copyWith(
//           colorScheme: ColorScheme.dark(
//             primary: HexColor('#036eb7'),
//             onPrimary: Colors.white,
//             surface: HexColor('#1a1a2e'),
//             onSurface: Colors.white,
//           ),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null) onPicked(picked);
//   }

//   Future<void> _saveTimeWindows() async {
//     await _prefs.saveWifiCheckinWindow(
//         _checkinStart.hour, _checkinStart.minute,
//         _checkinEnd.hour, _checkinEnd.minute);
//     await _prefs.saveWifiCheckoutWindow(
//         _checkoutStart.hour, _checkoutStart.minute,
//         _checkoutEnd.hour, _checkoutEnd.minute);
//     _showSnack('Time windows saved ✅');
//   }

//   void _showSnack(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text(message)));
//   }

//   String _sessionLabel(String status) {
//     switch (status) {
//       case 'checked_in':
//         return '🟢 Checked In';
//       case 'on_break':
//         return '🟡 On Break';
//       case 'checked_out':
//         return '🔴 Checked Out';
//       default:
//         return '⚪ Not Started';
//     }
//   }

//   String _formatBreakMinutes(int minutes) {
//     if (minutes == 0) return '0m';
//     final h = minutes ~/ 60;
//     final m = minutes % 60;
//     if (h > 0) return '${h}h ${m}m';
//     return '${m}m';
//   }

//   int _currentBreakElapsedMinutes() {
//     if (_currentBreakStart.isEmpty || _sessionStatus != 'on_break') return 0;
//     final parts = _currentBreakStart.split(':');
//     if (parts.length != 2) return 0;
//     final now = DateTime.now();
//     final h = int.tryParse(parts[0]) ?? now.hour;
//     final m = int.tryParse(parts[1]) ?? now.minute;
//     final start = DateTime(now.year, now.month, now.day, h, m);
//     return now.difference(start).inMinutes;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: RadialDecoration(),
//       child: Scaffold(
//         backgroundColor: Colors.transparent,
//         appBar: AppBar(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
//             onPressed: () => Navigator.pop(context),
//           ),
//           title: const Text(
//             'WiFi Auto Attendance',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//         ),
//         body: _loading
//             ? const Center(child: CircularProgressIndicator(color: Colors.white))
//             : SingleChildScrollView(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // ── Today's Activity Dashboard ──────────────────
//                     if (_enabled) ...[
//                       _sectionTitle("Today's Activity"),
//                       _buildActivityDashboard(),
//                       const SizedBox(height: 12),
//                       // ── Break Log ─────────────────────────────────
//                       if (_breakLog.isNotEmpty) ...[
//                         _sectionTitle('Break History'),
//                         _buildBreakLog(),
//                         const SizedBox(height: 12),
//                       ],
//                     ],

//                     // ── Status card ─────────────────────────────────
//                     _Card(
//                       child: Row(
//                         children: [
//                           const Icon(Icons.info_outline,
//                               color: Colors.white70, size: 20),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'Today\'s session: ${_sessionLabel(_sessionStatus)}',
//                               style: const TextStyle(
//                                   color: Colors.white70, fontSize: 13),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 12),

//                     // ── Enable toggle ───────────────────────────────
//                     _Card(
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           const Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text('Enable Auto Attendance',
//                                     style: TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 15)),
//                                 SizedBox(height: 4),
//                                 Text(
//                                   'Automatically check in/out when connected to office WiFi. Runs in background.',
//                                   style: TextStyle(
//                                       color: Colors.white60, fontSize: 12),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           Switch(
//                             value: _enabled,
//                             onChanged: _toggleEnabled,
//                             activeThumbColor: HexColor('#036eb7'),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 12),

//                     // ── Office WiFi ─────────────────────────────────
//                     _sectionTitle('Office WiFi'),
//                     _Card(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           if (_serverSsids.isNotEmpty) ...[
//                             for (int i = 0; i < _serverSsids.length; i++) ...[
//                               _InfoRow(
//                                 icon: Icons.wifi,
//                                 label: 'SSID',
//                                 value: (_serverSsids[i] is Map
//                                         ? (_serverSsids[i]['ssid'] ?? _serverSsids[i]['bssid'] ?? '')
//                                         : _serverSsids[i].toString())
//                                     .toString(),
//                               ),
//                               if (_serverSsids[i] is Map && _serverSsids[i]['bssid'] != null) ...[
//                                 const SizedBox(height: 4),
//                                 _InfoRow(
//                                   icon: Icons.router,
//                                   label: 'BSSID',
//                                   value: _serverSsids[i]['bssid'].toString(),
//                                 ),
//                               ],
//                               if (i < _serverSsids.length - 1)
//                                 const Divider(color: Colors.white12, height: 12),
//                             ],
//                             const SizedBox(height: 12),
//                           ] else if (_officeBssid.isNotEmpty) ...[
//                             _InfoRow(
//                                 icon: Icons.wifi,
//                                 label: 'SSID',
//                                 value: _officeSsid.isNotEmpty
//                                     ? _officeSsid
//                                     : '(unknown)'),
//                             const SizedBox(height: 6),
//                             _InfoRow(
//                                 icon: Icons.router,
//                                 label: 'BSSID',
//                                 value: _officeBssid),
//                             const SizedBox(height: 12),
//                           ] else
//                             const Padding(
//                               padding: EdgeInsets.only(bottom: 12),
//                               child: Text(
//                                 'No office WiFi configured yet. Tap the button below to sync from server.',
//                                 style: TextStyle(
//                                     color: Colors.white60, fontSize: 13),
//                               ),
//                             ),
//                           SizedBox(
//                             width: double.infinity,
//                             child: ElevatedButton.icon(
//                               onPressed: _syncServerSsids,
//                               icon: const Icon(Icons.sync),
//                               label: Text(_serverSsids.isNotEmpty
//                                   ? 'Re-sync Office WiFi'
//                                   : 'Sync Office WiFi'),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: HexColor('#036eb7'),
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8)),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 12),

//                     // ── Check-in window ─────────────────────────────
//                     _sectionTitle('Check-In Window'),
//                     _Card(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Auto check-in only happens if you connect during this time range.',
//                             style:
//                                 TextStyle(color: Colors.white60, fontSize: 12),
//                           ),
//                           const SizedBox(height: 12),
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: _TimeButton(
//                                   label: 'From',
//                                   time: _checkinStart,
//                                   onTap: () => _pickTime(
//                                     _checkinStart,
//                                     'Check-In Window Start',
//                                     (t) => setState(() => _checkinStart = t),
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: _TimeButton(
//                                   label: 'To',
//                                   time: _checkinEnd,
//                                   onTap: () => _pickTime(
//                                     _checkinEnd,
//                                     'Check-In Window End',
//                                     (t) => setState(() => _checkinEnd = t),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 12),

//                     // ── Check-out window ────────────────────────────
//                     _sectionTitle('Check-Out Window'),
//                     _Card(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Final check-out is recorded when you disconnect during this window. Outside this window, disconnects are treated as breaks.',
//                             style:
//                                 TextStyle(color: Colors.white60, fontSize: 12),
//                           ),
//                           const SizedBox(height: 12),
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: _TimeButton(
//                                   label: 'From',
//                                   time: _checkoutStart,
//                                   onTap: () => _pickTime(
//                                     _checkoutStart,
//                                     'Check-Out Window Start',
//                                     (t) => setState(
//                                         () => _checkoutStart = t),
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: _TimeButton(
//                                   label: 'To',
//                                   time: _checkoutEnd,
//                                   onTap: () => _pickTime(
//                                     _checkoutEnd,
//                                     'Check-Out Window End',
//                                     (t) => setState(() => _checkoutEnd = t),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 16),

//                     // ── Save button ─────────────────────────────────
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         onPressed: _saveTimeWindows,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: HexColor('#036eb7'),
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10)),
//                         ),
//                         child: const Text('Save Time Windows',
//                             style: TextStyle(
//                                 fontSize: 16, fontWeight: FontWeight.bold)),
//                       ),
//                     ),
//                     const SizedBox(height: 20),

//                     // ── How it works ────────────────────────────────
//                     _sectionTitle('How It Works'),
//                     _Card(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: const [
//                           _BulletPoint(
//                               '🏢 Connect to office WiFi during the check-in window → Auto Check-In'),
//                           SizedBox(height: 8),
//                           _BulletPoint(
//                               '🚶 Leave office WiFi (before checkout window) → Break Started'),
//                           SizedBox(height: 8),
//                           _BulletPoint(
//                               '🔄 Reconnect to office WiFi → Break Ended & Checked In'),
//                           SizedBox(height: 8),
//                           _BulletPoint(
//                               '🏠 Disconnect during checkout window → Final Check-Out'),
//                           SizedBox(height: 8),
//                           _BulletPoint(
//                               '📶 WiFi turned off → Periodic reminder to turn it on'),
//                           SizedBox(height: 8),
//                           _BulletPoint(
//                               '⏱ All mid-day disconnects are tracked as breaks with duration'),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 30),
//                   ],
//                 ),
//               ),
//       ),
//     );
//   }

//   // ── Today's Activity Dashboard widget ─────────────────────

//   Widget _buildActivityDashboard() {
//     final currentBreakElapsed = _currentBreakElapsedMinutes();
//     final effectiveBreakMinutes = _totalBreakMinutes + currentBreakElapsed;

//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Status row
//           Row(
//             children: [
//               _StatusIcon(status: _sessionStatus),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       _sessionLabel(_sessionStatus),
//                       style: const TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 16),
//                     ),
//                     if (_sessionStatus == 'on_break' &&
//                         _currentBreakStart.isNotEmpty)
//                       Text(
//                         'Break started at $_currentBreakStart (${_formatBreakMinutes(currentBreakElapsed)} ago)',
//                         style: const TextStyle(
//                             color: Colors.amberAccent, fontSize: 12),
//                       ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const Divider(color: Colors.white24, height: 24),

//           // Time details grid
//           Row(
//             children: [
//               Expanded(
//                 child: _DashboardStat(
//                   icon: Icons.login,
//                   label: 'Check-In',
//                   value: _firstCheckinTime.isNotEmpty
//                       ? _firstCheckinTime
//                       : '--:--',
//                   color: Colors.greenAccent,
//                 ),
//               ),
//               Expanded(
//                 child: _DashboardStat(
//                   icon: Icons.logout,
//                   label: 'Check-Out',
//                   value: _lastCheckoutTime.isNotEmpty
//                       ? _lastCheckoutTime
//                       : '--:--',
//                   color: Colors.redAccent,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(
//                 child: _DashboardStat(
//                   icon: Icons.coffee,
//                   label: 'Breaks',
//                   value: '${_breakLog.length}',
//                   color: Colors.orangeAccent,
//                 ),
//               ),
//               Expanded(
//                 child: _DashboardStat(
//                   icon: Icons.timer,
//                   label: 'Break Time',
//                   value: _formatBreakMinutes(effectiveBreakMinutes),
//                   color: Colors.amberAccent,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Break Log widget ──────────────────────────────────────

//   Widget _buildBreakLog() {
//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           for (int i = 0; i < _breakLog.length; i++) ...[
//             Row(
//               children: [
//                 Container(
//                   width: 24,
//                   height: 24,
//                   decoration: BoxDecoration(
//                     color: Colors.orangeAccent.withValues(alpha: 0.2),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Center(
//                     child: Text(
//                       '${i + 1}',
//                       style: const TextStyle(
//                           color: Colors.orangeAccent,
//                           fontSize: 11,
//                           fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Text(
//                   '${_breakLog[i]['start']} → ${_breakLog[i]['end']}',
//                   style: const TextStyle(color: Colors.white, fontSize: 13),
//                 ),
//                 const Spacer(),
//                 Text(
//                   '${_breakLog[i]['minutes']}m',
//                   style: const TextStyle(
//                       color: Colors.amberAccent,
//                       fontSize: 13,
//                       fontWeight: FontWeight.w600),
//                 ),
//               ],
//             ),
//             if (i < _breakLog.length - 1)
//               const Divider(color: Colors.white12, height: 16),
//           ],
//           if (_sessionStatus == 'on_break' &&
//               _currentBreakStart.isNotEmpty) ...[
//             if (_breakLog.isNotEmpty)
//               const Divider(color: Colors.white12, height: 16),
//             Row(
//               children: [
//                 Container(
//                   width: 24,
//                   height: 24,
//                   decoration: BoxDecoration(
//                     color: Colors.amberAccent.withValues(alpha: 0.2),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Center(
//                     child: Text(
//                       '${_breakLog.length + 1}',
//                       style: const TextStyle(
//                           color: Colors.amberAccent,
//                           fontSize: 11,
//                           fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Text(
//                   '$_currentBreakStart → …',
//                   style: const TextStyle(color: Colors.white, fontSize: 13),
//                 ),
//                 const Spacer(),
//                 Text(
//                   '${_currentBreakElapsedMinutes()}m (ongoing)',
//                   style: const TextStyle(
//                       color: Colors.amberAccent, fontSize: 12),
//                 ),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _sectionTitle(String title) => Padding(
//         padding: const EdgeInsets.only(bottom: 6, left: 2),
//         child: Text(
//           title,
//           style: const TextStyle(
//               color: Colors.white,
//               fontSize: 13,
//               fontWeight: FontWeight.bold,
//               letterSpacing: 0.5),
//         ),
//       );
// }

// // ─────────────────────────────────────────────────────────────
// // Reusable local widgets
// // ─────────────────────────────────────────────────────────────

// class _Card extends StatelessWidget {
//   final Widget child;
//   const _Card({required this.child});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.black.withValues(alpha: 0.35),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.white12),
//       ),
//       child: child,
//     );
//   }
// }

// class _InfoRow extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final String value;
//   const _InfoRow(
//       {required this.icon, required this.label, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, color: Colors.white54, size: 16),
//         const SizedBox(width: 6),
//         Text('$label: ',
//             style: const TextStyle(
//                 color: Colors.white60,
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500)),
//         Expanded(
//           child: Text(value,
//               style: const TextStyle(color: Colors.white, fontSize: 13),
//               overflow: TextOverflow.ellipsis),
//         ),
//       ],
//     );
//   }
// }

// class _TimeButton extends StatelessWidget {
//   final String label;
//   final TimeOfDay time;
//   final VoidCallback onTap;
//   const _TimeButton(
//       {required this.label, required this.time, required this.onTap});

//   String _fmt(TimeOfDay t) =>
//       '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
//         decoration: BoxDecoration(
//           color: Colors.white10,
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: Colors.white24),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(label,
//                 style: const TextStyle(color: Colors.white54, fontSize: 11)),
//             const SizedBox(height: 4),
//             Row(
//               children: [
//                 const Icon(Icons.access_time,
//                     color: Colors.white70, size: 16),
//                 const SizedBox(width: 4),
//                 Text(_fmt(time),
//                     style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold)),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _BulletPoint extends StatelessWidget {
//   final String text;
//   const _BulletPoint(this.text);

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Expanded(
//             child: Text(text,
//                 style:
//                     const TextStyle(color: Colors.white70, fontSize: 13))),
//       ],
//     );
//   }
// }

// class _StatusIcon extends StatelessWidget {
//   final String status;
//   const _StatusIcon({required this.status});

//   @override
//   Widget build(BuildContext context) {
//     Color color;
//     IconData icon;
//     switch (status) {
//       case 'checked_in':
//         color = Colors.greenAccent;
//         icon = Icons.check_circle;
//         break;
//       case 'on_break':
//         color = Colors.amberAccent;
//         icon = Icons.pause_circle_filled;
//         break;
//       case 'checked_out':
//         color = Colors.redAccent;
//         icon = Icons.cancel;
//         break;
//       default:
//         color = Colors.white38;
//         icon = Icons.radio_button_unchecked;
//     }
//     return Container(
//       width: 44,
//       height: 44,
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.15),
//         borderRadius: BorderRadius.circular(22),
//       ),
//       child: Icon(icon, color: color, size: 28),
//     );
//   }
// }

// class _DashboardStat extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final String value;
//   final Color color;
//   const _DashboardStat({
//     required this.icon,
//     required this.label,
//     required this.value,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, color: color, size: 18),
//         const SizedBox(width: 6),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(label,
//                 style: const TextStyle(color: Colors.white54, fontSize: 11)),
//             Text(value,
//                 style: TextStyle(
//                     color: color, fontSize: 15, fontWeight: FontWeight.bold)),
//           ],
//         ),
//       ],
//     );
//   }
// }
