
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
    print("SplashScreen: initState called");
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      try {
        print("SplashScreen: PostFrameCallback started");
        Preferences preferences = Preferences();
        print("SplashScreen: Preferences initialized");
        
        bool hardReset = await preferences.getHardReset();
        print("SplashScreen: Hard reset status: $hardReset");
        
        if (hardReset) {
          print("SplashScreen: Clearing preferences and navigating to login");
          preferences.clearPrefs();
          Navigator.pushReplacementNamed(context, LoginScreen.routeName);
          preferences.saveHardReset(false);
        } else {
          String token = await preferences.getToken();
          print("SplashScreen: Token: ${token.isEmpty ? 'empty' : 'present'}");
          
          if (token == '') {
            print("SplashScreen: No token, navigating to login");
            Navigator.pushReplacementNamed(context, LoginScreen.routeName);
          } else {
            print("SplashScreen: Token present, navigating to dashboard");
            Navigator.pushReplacementNamed(context, DashboardScreen.routeName);
          }
        }
      } catch (e) {
        print("SplashScreen: Error in navigation logic: $e");
        // Fallback to login screen on error
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    print("SplashScreen: build method called");
    return Scaffold(
      backgroundColor: HexColor(getAppTheme() ? radialBoxTheme : "#000000"),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Container(
                  width: 150,
                  height: 150,
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
                      width: 78,
                      height: 78,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              SizedBox(height: 20),
              CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
