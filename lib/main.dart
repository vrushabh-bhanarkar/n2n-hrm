import 'dart:io';
import 'dart:async';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/auth.dart';
import 'package:cnattendance/provider/attendancereportprovider.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/leaveprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/provider/payslipdetailprovider.dart';
import 'package:cnattendance/provider/payslipprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/provider/profileprovider.dart';
import 'package:cnattendance/screen/splashscreen.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/screen/auth/logout_pending_screen.dart';
import 'package:cnattendance/screen/profile/editprofilescreen.dart';
import 'package:cnattendance/screen/profile/payslipdetailscreen.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/utils/api_logger.dart';
import 'package:cnattendance/services/fcm_service.dart'
    show FCMService, fcmBackgroundMessageHandler;
import 'package:cnattendance/services/app_lifecycle_service.dart';
import 'package:cnattendance/services/realtime_chat_service.dart';
import 'package:cnattendance/services/notification_service.dart';
import 'package:cnattendance/services/notification_controller.dart';
import 'package:cnattendance/services/security_service.dart';
import 'package:cnattendance/services/wifi_attendance_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:in_app_notification/in_app_notification.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

/// Initialize awesome_notifications with required channels
Future<void> _initializeAwesomeNotifications() async {
  try {
    // Disable awesome_notifications action processing during cold-start
    // to prevent automatic navigation from stale notifications
    NotificationController.disableAwesomeNotificationsProcessing();

    await AwesomeNotifications().initialize(
      'resource://drawable/app_icon',
      [
        NotificationChannel(
          channelKey: 'digital_hr_channel',
          channelName: 'Digital HR Notifications',
          channelDescription: 'Notifications for HR events and reminders',
          defaultColor: Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'chat_channel',
          channelName: 'Chat Messages',
          channelDescription: 'Notifications for chat messages',
          defaultColor: Color(0xFF2196F3),
          ledColor: Colors.white,
          importance: NotificationImportance.Max,
          playSound: true,
          enableVibration: true,
        ),
        // TEMP: WiFi auto attendance notifications are disabled.
        // NotificationChannel(
        //   channelKey: 'wifi_attendance_channel',
        //   channelName: 'WiFi Auto Attendance',
        //   channelDescription: 'Notifications for automatic WiFi-based attendance',
        //   defaultColor: Color(0xFF4CAF50),
        //   ledColor: Colors.white,
        //   importance: NotificationImportance.High,
        //   playSound: true,
        //   enableVibration: true,
        // ),
      ],
    );
  } catch (e) {
    if (kDebugMode)
      debugPrint('❌ Error initializing Awesome Notifications: $e');
  }
}

/// Request notification permissions for both platforms
Future<void> _requestNotificationPermissions() async {
  try {
    // Request FCM permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Android-specific permission handling
    if (Platform.isAndroid) {
      // Request notification permission only for Android 13+
      if (Platform.version.contains('Android 13')) {
        await Permission.notification.request();
      }
    }
  } catch (e) {
    if (kDebugMode)
      debugPrint('❌ Error requesting notification permissions: $e');
  }
}

/// Request permissions needed for WiFi auto attendance.
Future<void> _requestWifiAttendancePermissions() async {
  try {
    if (!Platform.isAndroid) {
      return;
    }

    await Permission.locationWhenInUse.request();

    try {
      await Permission.nearbyWifiDevices.request();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Nearby WiFi devices permission request failed: $e');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error requesting WiFi attendance permissions: $e');
    }
  }
}

/// Initialize messaging and notification services (optimized for fast chat notification response)
Future<void> _initializeMessagingServices() async {
  try {
    if (kDebugMode) debugPrint('📱 Initializing messaging services...');

    // Set background message handler FIRST (critical for notifications)
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundMessageHandler);
    if (kDebugMode) debugPrint('✅ Background message handler set');

    // Initialize notification service FIRST (enables chat notification flow)
    await NotificationService.initialize();
    if (kDebugMode) debugPrint('✅ Notification service initialized');

    // Initialize FCMService FIRST to handle incoming notifications immediately
    await FCMService.initialize();
    if (kDebugMode) debugPrint('✅ FCM service initialized');

    // Request permissions early (non-blocking for notification processing)
    await _requestNotificationPermissions();
    if (kDebugMode) debugPrint('✅ Notification permissions requested');

    // Request WiFi/location permissions needed for auto attendance.
    await _requestWifiAttendancePermissions();
    if (kDebugMode) debugPrint('✅ WiFi attendance permissions requested');

    // Initialize non-critical services in background to avoid blocking notification navigation
    // These are deferred to allow chat notifications to navigate immediately
    Future<void> initializeBackgroundServices() async {
      try {
        // Realtime chat service - defer initialization
        await RealtimeChatService.initialize();
        if (kDebugMode) debugPrint('✅ Realtime chat service initialized');

        // App lifecycle service - defer initialization
        AppLifecycleService().initialize();
        if (kDebugMode) debugPrint('✅ App lifecycle service initialized');
      } catch (e) {
        if (kDebugMode)
          debugPrint('⚠️ Error initializing background services: $e');
      }
    }

    // Fire and forget - don't wait for these
    unawaited(initializeBackgroundServices());
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('❌ Error initializing messaging services: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    // Don't rethrow - allow app to continue
  }
}

Future<bool> _runStartupStep(
  Future<void> future,
  String label, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    await future.timeout(timeout);
    return true;
  } on TimeoutException {
    if (kDebugMode) {
      debugPrint(
          '⚠️ $label timed out after ${timeout.inSeconds}s; continuing startup');
    }
    return false;
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('⚠️ $label failed: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    return false;
  }
}

/// Helper for fire-and-forget futures
void unawaited(Future<void> future) {
  future.catchError((e) {
    if (kDebugMode) debugPrint('⚠️ Error in background initialization: $e');
  });
}

Future<void> _initializeDeferredStartupServices() async {
  await _runStartupStep(GetStorage.init(), 'GetStorage init');
  await _runStartupStep(
    _disableScreenshots(),
    'disable screenshots',
  );
  await _runStartupStep(
    _disableWifiAttendanceNotifications(),
    'disable WiFi attendance notifications',
  );

  ApiLogger.setEnabled(kDebugMode);
  if (kDebugMode) {
    debugPrint('✅ API Logging enabled for debug mode');
  }

  await _runStartupStep(
    _initializeAwesomeNotifications(),
    'awesome notifications',
  );
  NotificationController.initStartupTime();
  if (kDebugMode) debugPrint('✅ Awesome notifications initialized');

  await _runStartupStep(
    _initializeMessagingServices(),
    'messaging services',
  );

  await _runStartupStep(
    () async {
      final data =
          await PlatformAssetBundle().load('assets/ca/lets-encrypt-r3.pem');
      SecurityContext.defaultContext
          .setTrustedCertificatesBytes(data.buffer.asUint8List());
    }(),
    'SSL certificate',
  );

  if (Platform.isAndroid) {
    await _runStartupStep(
      FlutterDisplayMode.setHighRefreshRate(),
      'high refresh rate',
    );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(() async {
      try {
        await WifiAttendanceService.initialize();
        if (kDebugMode) debugPrint('✅ WiFi attendance service initialized');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ WiFi attendance service init failed: $e');
        }
      }
    }());
  });

  configLoading();
}

/// Prevent screenshots and screen recordings on Android using FLAG_SECURE
Future<void> _disableScreenshots() async {
  try {
    await SecurityService.disableScreenshots();
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('❌ Failed to disable screenshots: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}

/// Disable old WiFi auto-attendance notifications and channel leftovers.
Future<void> _disableWifiAttendanceNotifications() async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // Cancel known WiFi attendance notification IDs.
    for (final id in [888, 889, 890, 891, 892, 893]) {
      await plugin.cancel(id);
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️ Failed to disable WiFi attendance notifications: $e');
    }
  }
}

Future<String> _resolveInitialRoute() async {
  final preferences = Preferences();

  try {
    final hardReset = await preferences.getHardReset();
    if (hardReset) {
      await preferences.clearPrefs();
      preferences.saveHardReset(false);
      return LoginScreen.routeName;
    }

    final token = await preferences.getToken();
    return token.isEmpty ? LoginScreen.routeName : DashboardScreen.routeName;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️ Failed to resolve initial route: $e');
    }
    return LoginScreen.routeName;
  }
}

class _BootSplashApp extends StatelessWidget {
  const _BootSplashApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _BootSplashView(),
    );
  }
}

class _BootSplashView extends StatelessWidget {
  const _BootSplashView();

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

Future<void> main() async {
  try {
    if (kDebugMode) debugPrint('🚀 Starting app initialization...');

    // Initialize Flutter bindings
    WidgetsFlutterBinding.ensureInitialized();
    if (kDebugMode) debugPrint('✅ Flutter bindings initialized');

    // Show a real splash immediately so startup never appears blank.
    runApp(const _BootSplashApp());

    // Initialize localization
    // Note: flutter_translate 4.1.0 is incompatible with Flutter 3.41.4 (binary asset manifest)
    // We'll attempt initialization with error recovery
    if (kDebugMode) debugPrint('🌍 Initializing localization...');
    late LocalizationDelegate delegate;
    try {
      delegate = await LocalizationDelegate.create(
        fallbackLocale: 'en_US',
        supportedLocales: [
          'en_US',
          'ar',
          'es',
          'ne',
          'fa',
          'in',
          'pt',
          'ru',
          'de',
          'tr',
          'fr'
        ],
      );
      if (kDebugMode) debugPrint('✅ Localization initialized');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('⚠️ Warning: Localization initialization failed: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      // Rethrow to let the outer catch handle it
      // This ensures proper fallback initialization
      rethrow;
    }

    // Initialize Firebase (check if already initialized to avoid hot reload issues)
    try {
      if (kDebugMode) debugPrint('🔥 Starting Firebase initialization...');
      if (Firebase.apps.isEmpty) {
        if (kDebugMode)
          debugPrint('🔥 No Firebase apps found, initializing...');
        final firebaseReady = await _runStartupStep(
          Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform),
          'Firebase initialization',
          timeout: const Duration(seconds: 12),
        );
        if (firebaseReady && kDebugMode) {
          debugPrint('✅ Firebase initialized successfully');
        }
      } else {
        if (kDebugMode) debugPrint('✅ Firebase already initialized');
      }
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        if (kDebugMode) debugPrint('✅ Firebase already initialized (native)');
      } else {
        if (kDebugMode) {
          debugPrint('❌ Firebase initialization error: $e');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Firebase initialization error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      // Don't rethrow - allow app to continue without Firebase
    }

    final initialRoute = await _resolveInitialRoute();

    // Start the app with all required wrappers
    runApp(
      LocalizedApp(
        delegate,
        InAppNotification(
          child: OverlaySupport(
            child: MyApp(initialRoute: initialRoute),
          ),
        ),
      ),
    );

    unawaited(_initializeDeferredStartupServices());

    // Initialize WiFi auto attendance after the first frame so it does not
    // compete with splash/dashboard rendering on startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        try {
          await WifiAttendanceService.initialize();
          if (kDebugMode) debugPrint('✅ WiFi attendance service initialized');
        } catch (e) {
          if (kDebugMode)
            debugPrint('⚠️ WiFi attendance service init failed: $e');
        }
      }());
    });

    // Configure loading overlay
    configLoading();
    print("Main: App initialized successfully");
  } catch (error, stackTrace) {
    print('❌ Fatal error during app initialization: $error');
    print('Stack trace: $stackTrace');

    // Fallback: Try to start the app with minimal configuration
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await GetStorage.init();

      // Initialize Firebase in fallback mode if not already done
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform);
          if (kDebugMode) debugPrint('✅ Firebase initialized in fallback mode');
        } catch (e) {
          if (kDebugMode)
            debugPrint(
                '⚠️ Firebase initialization failed in fallback mode: $e');
        }
      }

      // Initialize messaging services in fallback mode
      await _initializeMessagingServices();

      // Run app WITHOUT flutter_translate in fallback mode
      // safeTranslate() will use fallback translations automatically
      if (kDebugMode)
        print('⚠️ Starting app in fallback mode (no localization)');

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => Auth()),
            ChangeNotifierProvider(create: (_) => Preferences()),
            ChangeNotifierProvider(create: (_) => LeaveProvider()),
            ChangeNotifierProvider(create: (_) => PrefProvider()),
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
            ChangeNotifierProvider(create: (_) => AttendanceReportProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
            ChangeNotifierProvider(create: (_) => MoreScreenProvider()),
            ChangeNotifierProvider(create: (_) => PaySlipProvider()),
            ChangeNotifierProvider(create: (_) => PaySlipDetailProvider()),
            // ChangeNotifierProvider(create: (_) => WifiAttendanceProvider()),
          ],
          child: GetMaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: NavigationService.navigatorKey,
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: [
              Locale('en', 'US'),
            ],
            locale: Locale('en', 'US'),
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            initialRoute: '/',
            routes: {
              '/': (_) => SplashScreen(),
              '/login': (_) => LoginScreen(),
              '/dashboard': (_) => DashboardScreen(),
              EditProfileScreen.routeName: (_) => EditProfileScreen(),
              '/logout-pending': (_) => LogoutPendingScreen(),
            },
            builder: EasyLoading.init(),
          ),
        ),
      );
    } catch (fallbackError) {
      print('❌ Fallback initialization failed: $fallbackError');
      print('Stack trace: $fallbackError');

      // As a last resort, start with a basic MaterialApp with error display
      try {
        WidgetsFlutterBinding.ensureInitialized();
      } catch (_) {}

      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Initialization Error',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('$error',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14)),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Try to restart the app
                    main();
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ));
    }
  }
}

void configLoading() {
  EasyLoading.instance
    ..indicatorType = EasyLoadingIndicatorType.cubeGrid
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 50.0
    ..radius = 0.0
    ..progressColor = Colors.blue
    ..backgroundColor = Colors.white
    ..indicatorColor = Colors.blue
    ..textColor = Colors.black
    ..maskType = EasyLoadingMaskType.none
    ..userInteractions = false
    ..dismissOnTap = false;
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key, this.initialRoute = '/'}) : super(key: key);

  final String initialRoute;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Enable awesome_notifications processing early for faster chat navigation
    // Process the initial notification immediately after the first frame builds
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Process initial message and pending notifications (chat navigation happens here)
      await FCMService.processInitialMessageIfAny();
      await NotificationService.processPendingNotificationResponse();

      // Enable awesome_notifications action processing immediately after init
      // This allows user interactions with notifications to navigate without delay
      NotificationController.enableAwesomeNotificationsProcessing();
    });
  }

  @override
  void dispose() {
    _cleanupServices();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _cleanupServices() async {
    try {
      await NotificationService.cleanup();
    } catch (e) {
      print('Error cleaning up notification service: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // Lifecycle state handling is managed by FCM/AppLifecycle services.
    // Avoid reinitializing notification service on every resume/background
    // to prevent duplicate listeners, channel recreation logs, and jank.
    if (state == AppLifecycleState.detached) {
      await _cleanupServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Try to get the localization delegate safely
      final localizationDelegate = LocalizedApp.of(context).delegate;

      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => Auth()),
          ChangeNotifierProvider(create: (_) => Preferences()),
          ChangeNotifierProvider(create: (_) => LeaveProvider()),
          ChangeNotifierProvider(create: (_) => PrefProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => AttendanceReportProvider()),
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ChangeNotifierProvider(create: (_) => MoreScreenProvider()),
          ChangeNotifierProvider(create: (_) => PaySlipProvider()),
          ChangeNotifierProvider(create: (_) => PaySlipDetailProvider()),
        ],
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService.navigatorKey,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            localizationDelegate,
          ],
          supportedLocales: localizationDelegate.supportedLocales,
          locale: localizationDelegate.currentLocale,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          // Add routes for navigation
          initialRoute: widget.initialRoute,
          routes: {
            '/': (_) => GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SplashScreen(),
                ),
            '/login': (_) => LoginScreen(),
            '/dashboard': (_) => DashboardScreen(),
            EditProfileScreen.routeName: (_) => EditProfileScreen(),
            PaySlipDetailScreen.routeName: (_) => PaySlipDetailScreen(),
            '/logout-pending': (_) => LogoutPendingScreen(),
          },
          builder: EasyLoading.init(),
        ),
      );
    } catch (e) {
      print('Error building app: $e');
      // Fallback to basic Material app
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading...'),
              ],
            ),
          ),
        ),
        builder: EasyLoading.init(),
      );
    }
  }
}
