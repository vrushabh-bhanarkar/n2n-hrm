import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/widget/buttonborder.dart';

class LogOutBottomSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => LogOutBottomSheetState();
}

class LogOutBottomSheetState extends State<LogOutBottomSheet> {
  void logout() async {
    try {
      setState(() {
        showLoader();
      });
      final response = await Provider.of<MoreScreenProvider>(context, listen: false).logout();
      
      print('🔍 LOGOUT RESPONSE - StatusCode: ${response.statusCode}');
      print('🔍 LOGOUT RESPONSE - Message: ${response.message}');
      print('🔍 LOGOUT RESPONSE - Status: ${response.status}');
      
      setState(() {
        dismissLoader();
      });
      if (!mounted) {
        return;
      }
      
      // Check for pending first
      if (response.statusCode == 202) {
        print('✅ Navigating to PENDING screen');
        // IMPORTANT: Don't remove all routes - keep dashboard in stack
        // so when rejected, we can go back to dashboard
        Navigator.of(context, rootNavigator: true).pushNamed(
          '/logout-pending',
        );
      } else if (response.statusCode == 200 || response.statusCode == 401) {
        print('✅ Navigating to LOGIN screen');
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (BuildContext context) {
              return LoginScreen(initial: false);
            },
          ),
          (_) => false,
        );
      } else {
        print('⚠️ Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ LOGOUT ERROR: $e');
      NavigationService().showSnackBar("Log out Alert", e.toString());
      setState(() {
        dismissLoader();
      });
    }
  }

  void dismissLoader() {
    setState(() {
      EasyLoading.dismiss(animation: true);
    });
  }

  void showLoader() {
    setState(() {
      EasyLoading.show(
          status: "Logging Out, Please Wait..",
          maskType: EasyLoadingMaskType.black);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RadialDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  translate('common.log_out'),
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.white,
                    )),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                translate('common.log_out_alert'),
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(right: 5),
                      child: TextButton(
                          style: TextButton.styleFrom(
                              backgroundColor: HexColor("#036eb7"),
                              shape: ButtonBorder()),
                          onPressed: () async {
                            logout();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              translate('common.confirm'),
                              style: TextStyle(color: Colors.white),
                            ),
                          )),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: 5),
                      child: TextButton(
                          style: TextButton.styleFrom(
                              backgroundColor: HexColor("#036eb7"),
                              shape: ButtonBorder()),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              translate('common.go_back'),
                              style: TextStyle(color: Colors.white),
                            ),
                          )),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
