import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

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
    print("SplashScreen: build method called");
    final size = MediaQuery.sizeOf(context);
    final logoContainerSize = (size.shortestSide * 0.36).clamp(120.0, 156.0);
    final logoSize = logoContainerSize * 0.54;

    return Scaffold(
      backgroundColor: HexColor(getAppTheme() ? radialBoxTheme : "#000000"),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: logoContainerSize,
                height: logoContainerSize,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icons/launcher-icon.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.business,
                        color: Colors.white,
                        size: logoSize * 0.9,
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: 20),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
