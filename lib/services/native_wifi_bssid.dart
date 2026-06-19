import 'dart:developer';
import 'package:flutter/services.dart';

/// WiFi BSSID reader using the MethodChannel registered in MainActivity.
/// The channel "com.n2nhrm.apk.wifi" is registered in MainActivity.configureFlutterEngine
/// and uses WifiManager.connectionInfo.bssid which works in foreground.
class NativeWifiBssid {
  static const String _channelName = 'com.n2nhrm.apk.wifi';
  static const String _method = 'getWifiBssid';

  static Future<String> getWifiBssid() async {
    try {
      final channel = MethodChannel(_channelName);
      final String bssid = await channel.invokeMethod(_method);
      log('[NativeWifiBssid] BSSID read: "$bssid"');
      return bssid;
    } on PlatformException catch (e) {
      log('[NativeWifiBssid] Error reading BSSID: ${e.message}');
      return '';
    } on MissingPluginException catch (e) {
      log('[NativeWifiBssid] MethodChannel not available: ${e.message}');
      return '';
    } catch (e) {
      log('[NativeWifiBssid] Unexpected error: $e');
      return '';
    }
  }
}

