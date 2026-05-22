import 'dart:async';
import 'dart:ui';

import 'package:cnattendance/model/auth.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/fallback_localization.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/customqrscanner.dart';
import 'package:cnattendance/widget/showlanguage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:flutter_web_browser/flutter_web_browser.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:hexcolor/hexcolor.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cnattendance/services/logout_status_service.dart';
// import 'package:qr_bar_code_scanner_dialog/qr_bar_code_scanner_dialog.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';
  final bool initial;

  const LoginScreen({Key? key, this.initial = true}) : super(key: key);

  @override
  State<StatefulWidget> createState() => loginScreenState();
}

class loginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _form = GlobalKey<FormState>();

  bool _obscureText = true;
  bool _didInit = false;

  void _toggle() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  void didChangeDependencies() {
    if (!_didInit && widget.initial) {
      _didInit = true;
      context.read<Auth>().resetAppUrl();
      context.read<Auth>().getAppUrl();
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _form.currentState?.dispose();
    super.dispose();
  }

  var _isLoading = false;

  bool validateField(String value) {
    if (value.isEmpty) {
      return false;
    }
    return true;
  }

  validateValue() async {
    final value = _form.currentState!.validate();
    if (value) {
      loginUser();
    }
  }

  Future<void> scanQr() async {
    final result = await showCustomQrScanner(context);
    if (result != null && result.trim().isNotEmpty) {
      print('User typed: $result');
      context.read<Auth>().saveAppUrl(result);
    }
  }

  /*Future<void> loadQR() async {
    final MobileScannerController controller = MobileScannerController();

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      var analyzed = await controller.analyzeImage(image.path);
      if (analyzed != null) {
        if (analyzed.barcodes.isNotEmpty) {
          try {
            var image = analyzed.barcodes[0].displayValue;
            context.read<Auth>().saveAppUrl(image ?? "");
          } catch (e) {
            showToast(
                "Invalid QR Code. Please use a specific QR provided by the organization");
          }
        } else {
          showToast("No QR Code found");
        }
      } else {
        showToast("No QR Code found");
      }
    }
  }*/

  void loginUser() async {
    setState(() {
      _isLoading = true;
      EasyLoading.show(
          status: safeTranslate('loader.signing_in'),
          maskType: EasyLoadingMaskType.black);
    });

    try {
      // Before login, check logout approval status (backup to prevent logging in while pending)
      final logoutStatus = await LogoutStatusService.checkLogoutApprovalStatus();
      if (logoutStatus != null && logoutStatus['data'] != null) {
        final data = logoutStatus['data'];
        final isPending = data['is_logout_pending'] == true || data['action'] == 'wait';
        if (isPending) {
          // Show waiting for admin approval screen and block login
          Navigator.of(context).pushNamedAndRemoveUntil('/logout-pending', (route) => false);
          setState(() {
            _isLoading = false;
            EasyLoading.dismiss(animation: true);
          });
          return;
        }
      }
      // If approved or not found, allow login
      final response = await Provider.of<Auth>(context, listen: false)
          .login(_usernameController.text, _passwordController.text);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(response.message)));

      Navigator.of(context)
          .pushNamedAndRemoveUntil(DashboardScreen.routeName, (route) => false);
    } on TimeoutException catch (error) {
      print('Timeout error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection timeout. Please check your internet and try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (error) {
      print(error);
      if (!mounted) return;
      
      // Provide user-friendly error messages
      String errorMessage = error.toString();
      if (errorMessage.contains('SocketException') || errorMessage.contains('Failed host lookup')) {
        errorMessage = 'No internet connection. Please check your network.';
      } else if (errorMessage.contains('TimeoutException')) {
        errorMessage = 'Connection timeout. Server took too long to respond.';
      } else if (errorMessage.contains('HandshakeException')) {
        errorMessage = 'Security error. Please try again.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      // Ensure loading is always dismissed
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        EasyLoading.dismiss(animation: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasUrl = context.watch<Auth>().appUrl.isNotEmpty;
    return Container(
      decoration: backgroundDecoration(),
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Spacer(),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                        context: context,
                        useRootNavigator: true,
                        builder: (context) {
                          return ShowLanguage();
                        });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.language,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Form(
          key: _form,
          child: SingleChildScrollView(
            child: IgnorePointer(
              ignoring: _isLoading,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: !hasUrl
                    ? Container(
                        color: Colors.transparent,
                        height: MediaQuery.of(context).size.height,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0, right: 20.0),
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        try {
                                          await context.read<Auth>().skipAppUrl();
                                          if (mounted) {
                                            // ScaffoldMessenger.of(context)
                                            //     .showSnackBar(SnackBar(
                                            //   content: Text(translate(
                                            //           'welcome_screen.skip') +
                                            //       ' - Using default server'),
                                            //   duration: Duration(seconds: 2),
                                            // ));
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(e.toString()),
                                              duration: Duration(seconds: 2),
                                            ));
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        constraints: BoxConstraints(
                                          minWidth: 44,
                                          minHeight: 44,
                                        ),
                                        child: Text(
                                          safeTranslate("welcome_screen.skip"),
                                          style: TextStyle(
                                              fontSize: 16, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onLongPress: () {
                                        context.read<Auth>().skipAppUrl();
                                      },
                                      child: Image.asset(
                                        'assets/icons/launcher-icon.png',
                                        width: 150,
                                        height: 150,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    Container(
                                      width: MediaQuery.of(context).size.width,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                                style: TextButton.styleFrom(
                                                  backgroundColor:
                                                      HexColor("#036eb7"),
                                                  padding: EdgeInsets.zero,
                                                  shape: ButtonBorder(),
                                                ),
                                                onPressed: () {
                                                  scanQr();
                                                },
                                                child: Padding(
                                                  padding: EdgeInsets.all(20.0),
                                                  child: Text(
                                                    safeTranslate(
                                                        "welcome_screen.verify_button"),
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                )),
                                          ),
                                          /*SizedBox(
                                            width: 10,
                                          ),
                                          IconButton(
                                              onPressed: () {
                                                loadQR();
                                              },
                                              style: IconButton.styleFrom(
                                                shape: ButtonBorder(),
                                                backgroundColor:
                                                    HexColor("#036eb7")
                                                        .withOpacity(.7),
                                              ),
                                              icon: Padding(
                                                padding:
                                                    const EdgeInsets.all(6.0),
                                                child: Icon(
                                                  Icons.qr_code,
                                                  color: Colors.white,
                                                  size: 32,
                                                ),
                                              ))*/
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Container(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Image.asset(
                                  'assets/icons/launcher-icon.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              gaps(20),
                              Text(
                                safeTranslate("login_screen.login"),
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20),
                              ),
                              gaps(20),
                              textHeading(safeTranslate("login_screen.username")),
                              gaps(10),
                              TextFormField(
                                keyboardType: TextInputType.emailAddress,
                                keyboardAppearance: Brightness.dark,
                                style: TextStyle(color: Colors.white),
                                validator: (value) {
                                  if (!validateField(value!)) {
                                    return "Empty Field";
                                  }

                                  return null;
                                },
                                controller: _usernameController,
                                cursorColor: Colors.white,
                                decoration: InputDecoration(
                                  prefixIcon:
                                      Icon(Icons.person, color: Colors.white),
                                  labelStyle: TextStyle(color: Colors.white),
                                  fillColor: Colors.white24,
                                  filled: true,
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          topRight: Radius.circular(0),
                                          bottomLeft: Radius.circular(0),
                                          bottomRight: Radius.circular(10))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          topRight: Radius.circular(0),
                                          bottomLeft: Radius.circular(0),
                                          bottomRight: Radius.circular(10))),
                                  focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          topRight: Radius.circular(0),
                                          bottomLeft: Radius.circular(0),
                                          bottomRight: Radius.circular(10))),
                                  errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          topRight: Radius.circular(0),
                                          bottomLeft: Radius.circular(0),
                                          bottomRight: Radius.circular(10))),
                                ),
                              ),
                              gaps(10),
                              textHeading(safeTranslate("login_screen.password")),
                              gaps(10),
                              TextFormField(
                                obscureText: _obscureText,
                                keyboardAppearance: Brightness.dark,
                                style: TextStyle(color: Colors.white),
                                validator: (value) {
                                  if (!validateField(value!)) {
                                    return "Empty Field";
                                  }

                                  return null;
                                },
                                controller: _passwordController,
                                cursorColor: Colors.white,
                                decoration: InputDecoration(
                                  prefixIcon:
                                      Icon(Icons.lock, color: Colors.white),
                                  labelStyle: TextStyle(color: Colors.white),
                                  fillColor: Colors.white24,
                                  filled: true,
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          topRight: Radius.circular(0),
                                          bottomLeft: Radius.circular(0),
                                          bottomRight: Radius.circular(10))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          topRight: Radius.circular(0),
                                          bottomLeft: Radius.circular(0),
                                          bottomRight: Radius.circular(10))),
                                  focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          topRight: Radius.circular(0),
                                          bottomLeft: Radius.circular(0),
                                          bottomRight: Radius.circular(10))),
                                  errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          topRight: Radius.circular(0),
                                          bottomLeft: Radius.circular(0),
                                          bottomRight: Radius.circular(10))),
                                  suffixIcon: InkWell(
                                    onTap: _toggle,
                                    child: Icon(
                                      _obscureText
                                          ? FontAwesomeIcons.eye
                                          : FontAwesomeIcons.eyeSlash,
                                      size: 15.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              gaps(30),
                              button(),
                              gaps(20),
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    openBrowserTab(context.read<Auth>().appUrl);
                                  },
                                  child: Text(
                                      textAlign: TextAlign.left,
                                      style: TextStyle(color: Colors.white),
                                      safeTranslate(
                                          "login_screen.forget_password")),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      context.read<Auth>().resetAppUrl();
                                      _usernameController.clear();
                                      _passwordController.clear();
                                    },
                                    child: Text(
                                        textAlign: TextAlign.left,
                                        style: TextStyle(color: Colors.white),
                                        safeTranslate("login_screen.go_back")),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  openBrowserTab(String url) async {
    final base = url.endsWith('/') ? url : '$url/';
    final resetUrl = '${base}password/reset';
    await FlutterWebBrowser.openWebPage(
      url: resetUrl,
      customTabsOptions: const CustomTabsOptions(
        colorScheme: CustomTabsColorScheme.dark,
        shareState: CustomTabsShareState.on,
        instantAppsEnabled: true,
        showTitle: true,
        urlBarHidingEnabled: true,
      ),
      safariVCOptions: const SafariViewControllerOptions(
        barCollapsingEnabled: true,
        dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        modalPresentationCapturesStatusBarAppearance: true,
      ),
    );
  }

  BoxDecoration backgroundDecoration() {
    return BoxDecoration(
        image: DecorationImage(
      colorFilter: ColorFilter.mode(
          getAppTheme() ? Colors.blueGrey : Colors.black54,
          BlendMode.softLight),
      image: AssetImage(
        "assets/images/login.jpg",
      ),
      fit: BoxFit.cover,
    ));
  }

  Widget gaps(double value) {
    return SizedBox(
      height: value,
    );
  }

  Widget textHeading(String value) {
    return Text(
        textAlign: TextAlign.left,
        style: const TextStyle(color: Colors.white),
        value);
  }

  Widget button() {
    return Container(
      width: MediaQuery.of(context).size.width,
      child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: HexColor("#036eb7"),
            padding: EdgeInsets.zero,
            shape: ButtonBorder(),
          ),
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            validateValue();
          },
          child: const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'Login',
              style: TextStyle(color: Colors.white),
            ),
          )),
    );
  }
}
