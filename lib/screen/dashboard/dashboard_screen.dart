import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/dashboard/homescreen.dart';
import 'package:cnattendance/screen/dashboard/leavescreen.dart';
import 'package:cnattendance/screen/dashboard/attendancescreen.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
import 'package:cnattendance/services/wifi_background_service.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/fallback_localization.dart';
import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';
import 'package:hexcolor/hexcolor.dart';

class DashboardScreen extends StatefulWidget {
  static const String routeName = '/dashboard';

  @override
  State<StatefulWidget> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  bool _hasLoadedUser = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load attendance method
      try {
        if (mounted) {
          await context.read<PrefProvider>().getAttendanceType();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to load attendance method: $e');
      }

      // Initialize WiFi polling
      try {
        final preferences = Preferences();
        final token = await preferences.getToken();
        if (token.isNotEmpty) {
          await WifiBackgroundService().initialize();
          await WifiBackgroundService().start();
          debugPrint('✅ WiFi auto-attendance initialized');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to start WiFi polling: $e');
      }

      // Load user data
      if (!_hasLoadedUser && mounted) {
        _hasLoadedUser = true;
        context.read<PrefProvider>().getUser();
      }
    });
  }

  ItemConfig getItemConfig(IconData icon, String title) {
    return ItemConfig(
      icon: Icon(icon),
      activeColorSecondary: Colors.white,
      activeForegroundColor: Colors.white,
      inactiveBackgroundColor: Colors.white30,
      inactiveForegroundColor: Colors.white30,
      title: title,
    );
  }

  late final PersistentTabController _controller =
      PersistentTabController(initialIndex: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PersistentTabView(
        controller: _controller,
        backgroundColor: HexColor(getAppTheme() ? radialBoxTheme : "#000000"),
        handleAndroidBackButtonPress: true,
        resizeToAvoidBottomInset: true,
        stateManagement: true,

        tabs: [
          PersistentTabConfig(
              screen: HomeScreen(_controller),
              item: getItemConfig(
                Icons.home_filled,
                safeTranslate('dashboard_screen.home'),
              )),
          PersistentTabConfig(
              screen: LeaveScreen(),
              item: getItemConfig(
                Icons.sick,
                safeTranslate('dashboard_screen.leave'),
              )),
          PersistentTabConfig(
              screen: AttendanceScreen(),
              item: getItemConfig(
                Icons.co_present_outlined,
                safeTranslate('dashboard_screen.attendance'),
              )),
          PersistentTabConfig(
              screen: MoreScreen(),
              item: getItemConfig(
                Icons.more,
                safeTranslate('dashboard_screen.more'),
              )),
        ],
        navBarBuilder: (NavBarConfig) {
          return Style9BottomNavBar(
            navBarConfig: NavBarConfig,
            navBarDecoration: NavBarDecoration(color: HexColor(getAppTheme() ? radialBoxTheme : "#000000")),
          );
        },
      ),
    );
  }
}
