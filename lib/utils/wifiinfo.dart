import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WifiInfo {
  final info = NetworkInfo();

  static bool _isValidBssid(String? bssid) {
    if (bssid == null || bssid.isEmpty) return false;
    final normalized = bssid.trim().toLowerCase();
    if (normalized == '02:00:00:00:00:00') return false;
    if (normalized == '00:00:00:00:00:00') return false;
    final macRegex = RegExp(r'^([0-9a-f]{2}:){5}[0-9a-f]{2}$');
    return macRegex.hasMatch(normalized);
  }

  Future<String?> wifiname() async {
    return info.getWifiName();
  }

  Future<String?> wifiBSSID() async {
    final bssid = await info.getWifiBSSID();
    if (!_isValidBssid(bssid)) {
      debugPrint('[WifiInfo] Invalid BSSID detected: $bssid');
      return null;
    }
    return bssid;
  }

  Future<String?> wifiIP() async {
    return info.getWifiIP();
  }

  Future<String?> wifiIPv6() async {
    return info.getWifiIPv6();
  }

  Future<String?> wifiSubmask() async {
    return info.getWifiSubmask();
  }

  Future<String?> wifiBroadcast() async {
    return info.getWifiSubmask();
  }

  Future<String?> wifiGateway() async {
    return info.getWifiGatewayIP();
  }
}
