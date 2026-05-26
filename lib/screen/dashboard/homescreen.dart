import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
// ...existing code...
import 'package:cnattendance/screen/general/generalscreen.dart';
import 'package:cnattendance/services/wifi_attendance_service.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/fallback_localization.dart';
import 'package:cnattendance/utils/locationstatus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cnattendance/utils/wifiinfo.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:cnattendance/widget/homescreen/checkattendance.dart';
import 'package:cnattendance/widget/homescreen/myteam.dart';
import 'package:cnattendance/widget/homescreen/overviewdashboard.dart';
import 'package:cnattendance/widget/homescreen/recentAward.dart';
import 'package:cnattendance/widget/homescreen/recentEvent.dart';
import 'package:cnattendance/widget/homescreen/recentTraining.dart';
import 'package:cnattendance/widget/homescreen/upcomingholiday.dart';
import 'package:cnattendance/widget/homescreen/weeklyreportchart.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/widget/headerprofile.dart';
import 'package:quick_actions/quick_actions.dart';

class HomeScreen extends StatefulWidget {
  final PersistentTabController controller;

  HomeScreen(this.controller);

  @override
  State<StatefulWidget> createState() => HomeScreenState(controller);
}

class HomeScreenState extends State<HomeScreen> {
  QuickActions quickActions = const QuickActions();
  bool isEnabled = true;
  bool isLoading = false;
  bool _isDashboardLoading = false;
  bool _hasTriedAutoCheckin = false;
  DateTime? _lastDashboardErrorAt;
  DateTime? _lastWifiStatusRefreshAt;
  static const Duration _dashboardRetryBackoff = Duration(seconds: 20);
  static const Duration _wifiStatusRefreshThrottle = Duration(seconds: 10);
  static const Duration _wifiApiBackoffDuration = Duration(minutes: 10);

  PersistentTabController controller;

  HomeScreenState(this.controller);

  String _normalizeWifiValue(String? value) {
    return (value ?? '').trim().replaceAll('"', '').toLowerCase();
  }

  bool _isMacAddress(String value) {
    return RegExp(r'^[0-9a-f]{2}(:[0-9a-f]{2}){5}$').hasMatch(value);
  }

  bool _looksLikeHtml(String body) {
    final trimmed = body.trimLeft().toLowerCase();
    return trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html');
  }

  bool _isBackendUnavailableResponse(http.Response response) {
    if (response.isRedirect || response.statusCode == 302) {
      return true;
    }

    final lowerBody = response.body.toLowerCase();
    if (_looksLikeHtml(response.body)) {
      return true;
    }

    return lowerBody.contains('account suspended') ||
        lowerBody.contains('temporarily moved') ||
        lowerBody.contains('<title>302 found');
  }

  Future<bool> _isWifiApiBackoffActive() async {
    final sp = await SharedPreferences.getInstance();
    final untilMs = sp.getInt(Preferences.WIFI_API_BACKOFF_UNTIL_MS) ?? 0;
    return untilMs > DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _activateWifiApiBackoff(String reason) async {
    final sp = await SharedPreferences.getInstance();
    final until = DateTime.now().add(_wifiApiBackoffDuration);
    await sp.setInt(
      Preferences.WIFI_API_BACKOFF_UNTIL_MS,
      until.millisecondsSinceEpoch,
    );
    log('[HomeScreen] ⛔ Backend unavailable ($reason). Pausing auto WiFi check-in until $until');
  }

  bool _matchesOfficeWifi(
    List<dynamic> serverSsids, {
    required String? currentBssid,
    required String? currentSsid,
  }) {
    final bssidNorm = _normalizeWifiValue(currentBssid);
    final ssidNorm = _normalizeWifiValue(currentSsid);
    if (bssidNorm.isEmpty && ssidNorm.isEmpty) return false;

    for (final item in serverSsids) {
      if (item is Map) {
        final candidates = [
          item['bssid'],
          item['router_bssid'],
          item['ssid'],
          item['name'],
        ];
        for (final candidate in candidates) {
          final value = _normalizeWifiValue(candidate?.toString());
          if (value.isEmpty) continue;

          if (bssidNorm.isNotEmpty && value == bssidNorm) return true;
          if (!_isMacAddress(value) &&
              ssidNorm.isNotEmpty &&
              value == ssidNorm) {
            return true;
          }
        }
      } else {
        final value = _normalizeWifiValue(item.toString());
        if (value.isEmpty) continue;

        if (bssidNorm.isNotEmpty && value == bssidNorm) return true;
        if (!_isMacAddress(value) && ssidNorm.isNotEmpty && value == ssidNorm) {
          return true;
        }
      }
    }

    return false;
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) async {
        locationStatus();
        checkNotificationState();

        quickActions.initialize((type) async {
          if (type == "actionCheckIn") {
            await onCheckInShortCut();
          } else if (type == "actionCheckOut") {
            await onCheckOutShortCut();
          }
        });
        quickActions.setShortcutItems(<ShortcutItem>[
          ShortcutItem(
              type: 'actionCheckIn',
              localizedTitle: 'Check In',
              icon: 'check_in'),
          ShortcutItem(
              type: 'actionCheckOut',
              localizedTitle: 'Check Out',
              icon: 'check_out'),
        ]);

        await Provider.of<DashboardProvider>(context, listen: false)
            .getFeatures();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasTriedAutoCheckin) {
        _hasTriedAutoCheckin = true;
        _tryAutoWifiCheckIn();
      }
    });
    WifiAttendanceService.addStatusListener(_onWifiStatusChange);
    super.initState();
  }

  @override
  void dispose() {
    WifiAttendanceService.removeStatusListener(_onWifiStatusChange);
    super.dispose();
  }

  void _onWifiStatusChange() {
    if (mounted) {
      final now = DateTime.now();
      if (_lastWifiStatusRefreshAt != null &&
          now.difference(_lastWifiStatusRefreshAt!) <
              _wifiStatusRefreshThrottle) {
        return;
      }
      _lastWifiStatusRefreshAt = now;
      // Background service did an auto check-in/check-out, refresh dashboard
      loadDashboard();
    }
  }

  void checkNotificationState() {
    try {
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        print("FirebaseMessaging.getInitialMessage $message");
        if (message == null) {
          return;
        }
        Get.to(GeneralScreen(), arguments: {
          "title": message.data["title"],
          "message": message.data["message"],
          "date": ""
        });
      });
    } catch (e) {
      print("Firebase not initialized: $e");
    }
  }

  void locationStatus() async {
    try {
      Preferences preferences = Preferences();
      final position = await LocationStatus()
          .determinePosition(await preferences.getWorkSpace());

      if (!mounted) {
        return;
      }
      final location =
          Provider.of<DashboardProvider>(context, listen: false).locationStatus;

      location.update('latitude', (value) => position.latitude);
      location.update('longitude', (value) => position.longitude);

      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.setDouble('last_latitude', position.latitude);
      await sharedPreferences.setDouble('last_longitude', position.longitude);
    } catch (e) {
      print(e);
      showToast(e.toString());
    }
  }

  Future<void> onCheckInShortCut() async {
    Preferences pref = Preferences();
    if ((await pref.getToken()).isNotEmpty) {
      if ((await pref.getUserAuth())) {
        return;
      }
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      try {
        isLoading = true;
        setState(() {
          EasyLoading.show(
              status: safeTranslate('loader.requesting'),
              maskType: EasyLoadingMaskType.black);
        });
        var status = await provider.getCheckInStatus();
        if (status) {
          final response = await provider.checkInAttendance();
          isEnabled = true;
          if (!mounted) {
            return;
          }
          if (response.statusCode == 401) {
            // Do not auto-logout or navigate to login here. Keep the session
            // state in preferences and let user logout manually.
            return;
          }
          setState(() {
            EasyLoading.dismiss(animation: true);
            isLoading = false;
            showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  child: CustomAlertDialog(response.message),
                );
              },
            );
          });
        }
      } catch (e) {
        print(e);
        setState(() {
          EasyLoading.dismiss(animation: true);
          isLoading = false;
          showDialog(
            context: context,
            builder: (context) {
              return Dialog(
                child: CustomAlertDialog(e.toString()),
              );
            },
          );
        });
      }
    } else {
      showToast("Please Login First");
    }
  }

  Future<void> onCheckOutShortCut() async {
    Preferences pref = Preferences();
    if ((await pref.getToken()).isNotEmpty) {
      if ((await pref.getUserAuth())) {
        return;
      }
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      try {
        isLoading = true;
        setState(() {
          EasyLoading.show(
              status: "Requesting...", maskType: EasyLoadingMaskType.black);
        });
        var status = await provider.getCheckInStatus();
        if (status) {
          final response = await provider.checkOutAttendance();
          isEnabled = true;
          if (!mounted) {
            return;
          }
          if (response.statusCode == 401) {
            // Do not auto-logout or navigate to login here. Keep the session
            // state in preferences and let user logout manually.
            return;
          }
          setState(() {
            EasyLoading.dismiss(animation: true);
            isLoading = false;
            showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  child: CustomAlertDialog(response.message),
                );
              },
            );
          });
        }
      } catch (e) {
        print(e);
        setState(() {
          EasyLoading.dismiss(animation: true);
          isLoading = false;
          showDialog(
            context: context,
            builder: (context) {
              return Dialog(
                child: CustomAlertDialog(e.toString()),
              );
            },
          );
        });
      }
    } else {
      showToast("Please Login First");
    }
  }

  Future<String> loadDashboard() async {
    // Debounce: prevent multiple simultaneous dashboard loads
    if (_isDashboardLoading) return 'loading';

    // Back off dashboard retries after a server failure to avoid log spam.
    final now = DateTime.now();
    if (_lastDashboardErrorAt != null &&
        now.difference(_lastDashboardErrorAt!) < _dashboardRetryBackoff) {
      return 'backoff';
    }

    _isDashboardLoading = true;

    try {
      var fcm = await FirebaseMessaging.instance.getToken();
      print(fcm);
    } catch (e) {
      print("Firebase not initialized, skipping FCM token: $e");
    }

    try {
      final dashboardResponse =
          await Provider.of<DashboardProvider>(context, listen: false)
              .getDashboard();

      final user = dashboardResponse.data.user;

      Provider.of<PrefProvider>(context, listen: false).saveBasicUser(User(
          id: user.id,
          name: user.name,
          email: user.email,
          username: user.username,
          avatar: user.avatar,
          workspace_type: user.workspace_type));

      Provider.of<PrefProvider>(context, listen: false)
          .saveEngDateEnabled(dashboardResponse.data.dateInAd);

      if (!Provider.of<DashboardProvider>(context, listen: false)
          .isBirthdayWished) {
        showBirthdayWish();
      }

      _lastDashboardErrorAt = null;

      // Auto WiFi check-in: only try once per screen visit
      // (also triggered from initState independently)

      _isDashboardLoading = false;
      return 'loaded';
    } catch (e) {
      _lastDashboardErrorAt = DateTime.now();
      print(e);
      _isDashboardLoading = false;
      return 'loaded';
    }
  }

  /// Resolve coordinates without blocking on a fresh GPS fix.
  Future<(double latitude, double longitude)>
      _resolveAutoCheckInCoordinates() async {
    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final cachedLatitude = provider.locationStatus['latitude'] ?? 0.0;
      final cachedLongitude = provider.locationStatus['longitude'] ?? 0.0;
      if (cachedLatitude != 0.0 && cachedLongitude != 0.0) {
        return (cachedLatitude, cachedLongitude);
      }
    } catch (_) {}

    try {
      final sp = await SharedPreferences.getInstance();
      final cachedLatitude = sp.getDouble('last_latitude') ?? 0.0;
      final cachedLongitude = sp.getDouble('last_longitude') ?? 0.0;
      if (cachedLatitude != 0.0 && cachedLongitude != 0.0) {
        return (cachedLatitude, cachedLongitude);
      }
    } catch (_) {}

    try {
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return (lastKnownPosition.latitude, lastKnownPosition.longitude);
      }
    } catch (e) {
      log('[HomeScreen] Could not read last known location: $e');
    }

    return (0.0, 0.0);
  }

  /// Attempt auto WiFi check-in if on office WiFi and not already checked in.
  Future<void> _tryAutoWifiCheckIn() async {
    try {
      if (await _isWifiApiBackoffActive()) {
        log('[HomeScreen] Skipping auto check-in due to backend backoff');
        return;
      }

      final sp = await SharedPreferences.getInstance();
      final wifiAutoEnabled = sp.getBool(Preferences.WIFI_AUTO_ENABLED) ?? true;
      final attendanceType =
          _normalizeWifiValue(sp.getString('attendance_type') ?? 'default');
      if (!wifiAutoEnabled && attendanceType != 'wifi') {
        log('[HomeScreen] Skipping auto check-in because WiFi auto-attendance is disabled and attendance method is not WiFi');
        return;
      }

      // Check session status from SharedPreferences (works even if dashboard API fails)
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final sessionDate = sp.getString(Preferences.WIFI_SESSION_DATE) ?? '';
      final sessionStatus =
          sp.getString(Preferences.WIFI_SESSION_STATUS) ?? 'none';
      final hasTodaySession = sessionDate == todayStr;

      // If already checked out, never auto check-in again for today.
      if (hasTodaySession && sessionStatus == 'checked_out') {
        log('[HomeScreen] Already checked_out today, skipping auto check-in');
        return;
      }

      // Also check dashboard provider if available
      try {
        final provider = Provider.of<DashboardProvider>(context, listen: false);
        if (provider.attendanceList['check-in'] != '-') {
          log('[HomeScreen] Already checked in (from dashboard), skipping auto check-in');
          return;
        }
      } catch (_) {}

      // Check if on WiFi
      final results = await Connectivity().checkConnectivity();
      if (!results.contains(ConnectivityResult.wifi)) {
        log('[HomeScreen] Not on WiFi, skipping auto check-in');
        return;
      }

      // Get current BSSID/SSID
      final currentBssid = await WifiInfo().wifiBSSID();
      final currentSsid = await WifiInfo().wifiname();
      if (_normalizeWifiValue(currentBssid).isEmpty &&
          _normalizeWifiValue(currentSsid).isEmpty) {
        log('[HomeScreen] Could not read BSSID/SSID, skipping auto check-in');
        return;
      }
      log('[HomeScreen] Current BSSID: ${currentBssid ?? '(empty)'}');
      log('[HomeScreen] Current SSID: ${currentSsid ?? '(empty)'}');

      List<dynamic> authorizedWifiNetworks = [];
      try {
        final cachedSsidsJson =
            sp.getString(Preferences.WIFI_SERVER_SSIDS) ?? '[]';
        final decoded = jsonDecode(cachedSsidsJson);
        if (decoded is List) {
          authorizedWifiNetworks = decoded;
        }
      } catch (_) {}

      if (authorizedWifiNetworks.isEmpty) {
        final cachedOfficeBssid = _normalizeWifiValue(
          sp.getString(Preferences.WIFI_LAST_MATCHED_BSSID) ??
              sp.getString(Preferences.WIFI_OFFICE_BSSID),
        );
        if (cachedOfficeBssid.isNotEmpty) {
          authorizedWifiNetworks = [cachedOfficeBssid];
        }
      }

      if (authorizedWifiNetworks.isEmpty) {
        log('[HomeScreen] No cached office WiFi list available, skipping auto check-in');
        return;
      }

      if (!_matchesOfficeWifi(
        authorizedWifiNetworks,
        currentBssid: currentBssid,
        currentSsid: currentSsid,
      )) {
        log('[HomeScreen] Connected WiFi does not match office WiFi, skipping auto check-in');
        return;
      }

      // Avoid duplicate check-in API calls when local session already says checked_in.
      if (hasTodaySession && sessionStatus == 'checked_in') {
        log('[HomeScreen] Already checked_in today and on office WiFi, skipping duplicate check-in API call');
        return;
      }

      log('[HomeScreen] On office WiFi, attempting auto check-in...');

      final (latitude, longitude) = await _resolveAutoCheckInCoordinates();
      if (latitude == 0.0 && longitude == 0.0) {
        log('[HomeScreen] Using zero coordinates for auto check-in because no cached location was available');
      }

      // Call attendance API directly for WiFi check-in
      final currentBssidValue = _normalizeWifiValue(currentBssid);
      final fallbackBssid = _normalizeWifiValue(
        sp.getString(Preferences.WIFI_LAST_MATCHED_BSSID) ??
            sp.getString(Preferences.WIFI_OFFICE_BSSID),
      );
      final isPlaceholderBssid =
          currentBssidValue.isEmpty || currentBssidValue == '02:00:00:00:00:00';
      final bssidForApi = !isPlaceholderBssid &&
              currentBssid != null &&
              currentBssid.trim().isNotEmpty
          ? currentBssid.trim()
          : fallbackBssid;
      if (bssidForApi.isEmpty) {
        log('[HomeScreen] Office WiFi matched but no usable BSSID was available, skipping auto check-in API');
        return;
      }

      final preferences = Preferences();
      final token = await preferences.getToken();
      final uri = Uri.parse('${Constant.appUrl}${Constant.ATTENDANCE_URL}');
      final requestBody = {
        'attendance_type': 'wifi',
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'router_ssid': (currentSsid ?? '').replaceAll('"', ''),
        'router_bssid': bssidForApi,
        'identifier': '',
        'attendance_status_type': 'checkIn',
        'note': '',
      };

      log('[HomeScreen] Check-in API: POST $uri');
      log('[HomeScreen] Check-in body: $requestBody');

      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      log('[HomeScreen] Check-in response ${response.statusCode}: ${response.body}');

      if (_isBackendUnavailableResponse(response)) {
        await _activateWifiApiBackoff('attendance:${response.statusCode}');
        return;
      }

      if (response.statusCode == 200) {
        // Save matched BSSID for checkout
        final persisted = await SharedPreferences.getInstance();
        await persisted.setString(
            Preferences.WIFI_LAST_MATCHED_BSSID, bssidForApi);
        // Refresh dashboard to show updated check-in time
        try {
          Future<void>(() async {
            try {
              await Provider.of<DashboardProvider>(context, listen: false)
                  .getDashboard();
            } catch (_) {}
          });
        } catch (_) {}
        log('[HomeScreen] Auto WiFi check-in successful');
      }
    } catch (e) {
      log('[HomeScreen] Auto WiFi check-in failed: $e');
    }
  }

  void showBirthdayWish() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset('assets/raw/hbd.json'),
                  Lottie.asset('assets/raw/hbd_text.json'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final features = context.watch<DashboardProvider>().features;
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FocusDetector(
          onFocusGained: () {
            loadDashboard();
          },
          child: RefreshIndicator(
            triggerMode: RefreshIndicatorTriggerMode.onEdge,
            color: Colors.white,
            backgroundColor: Colors.blueGrey,
            edgeOffset: 50,
            onRefresh: () {
              return loadDashboard();
            },
            child: SafeArea(
                child: SingleChildScrollView(
              child: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HeaderProfile(),
                    CheckAttendance(),
                    OverviewDashboard(controller),
                    UpcomingHoliday(),
                    if (features["award"] == "1") RecentAward(),
                    if (features["event"] == "1") RecentEvent(),
                    if (features["training"] == "1") RecentTraining(),
                    WeeklyReportChart(),
                    MyTeam()
                  ],
                ),
              ),
            )),
          ),
        ),
      ),
    );
  }
}
