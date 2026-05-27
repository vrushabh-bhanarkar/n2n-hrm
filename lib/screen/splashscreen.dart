import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SplashState();
}

class SplashState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print("SplashScreen: initState called");
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final minDisplay = const Duration(milliseconds: 1500);
      final start = DateTime.now();
      String targetRoute = LoginScreen.routeName;
      try {
        print("SplashScreen: PostFrameCallback started");
        Preferences preferences = Preferences();
        print("SplashScreen: Preferences initialized");

        bool hardReset = await preferences.getHardReset();
        print("SplashScreen: Hard reset status: $hardReset");

        if (hardReset) {
          print(
              "SplashScreen: Clearing preferences and scheduling login navigation");
          await preferences.clearPrefs();
          preferences.saveHardReset(false);
          targetRoute = LoginScreen.routeName;
        } else {
          String token = await preferences.getToken();
          print("SplashScreen: Token: ${token.isEmpty ? 'empty' : 'present'}");
          if (token == '') {
            print("SplashScreen: No token, scheduling login navigation");
            targetRoute = LoginScreen.routeName;
          } else {
            print(
                "SplashScreen: Token present, scheduling dashboard navigation");
            targetRoute = DashboardScreen.routeName;
          }
        }
      } catch (e) {
        print("SplashScreen: Error in navigation logic: $e");
        targetRoute = LoginScreen.routeName;
      }

      final elapsed = DateTime.now().difference(start);
      if (elapsed < minDisplay) {
        await Future.delayed(minDisplay - elapsed);
      }

      if (!mounted) return;
      try {
        Navigator.pushReplacementNamed(context, targetRoute);
      } catch (e) {
        print("SplashScreen: Navigation failed: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = (size.shortestSide * 0.5).clamp(190.0, 250.0);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Center(
          child: Image.asset(
            'assets/icons/hrm-logo.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.business,
                color: Colors.white,
                size: 96,
              );
            },
          ),
        ),
      ),
    );
  }
}
