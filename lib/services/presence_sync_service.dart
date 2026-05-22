import 'dart:async';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PresenceSyncService {
  static final Preferences _preferences = Preferences();
  static Timer? _heartbeatTimer;
  static bool _syncInProgress = false;
  static const Duration _heartbeatInterval = Duration(seconds: 60);

  static void startForegroundSync({bool immediate = true}) {
    _heartbeatTimer?.cancel();

    if (immediate) {
      markOnlineViaBackend();
    }

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      markOnlineViaBackend();
    });

    if (kDebugMode) {
      debugPrint('✅ PresenceSync: foreground heartbeat started');
    }
  }

  static void stopForegroundSync() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (kDebugMode) {
      debugPrint('✅ PresenceSync: foreground heartbeat stopped');
    }
  }

  static Future<Map<String, double>> _resolveCoordinates(
      SharedPreferences storage) async {
    double latitude = storage.getDouble('last_latitude') ?? 0.0;
    double longitude = storage.getDouble('last_longitude') ?? 0.0;

    try {
      final permission = await Geolocator.checkPermission();
      final hasPermission = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (hasPermission && serviceEnabled) {
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (_) {
          position = await Geolocator.getLastKnownPosition();
        }

        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
          await storage.setDouble('last_latitude', latitude);
          await storage.setDouble('last_longitude', longitude);
        }
      }
    } catch (_) {
      // Keep cached values on any location error.
    }

    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Ping backend with last known location to help server refresh online_status.
  static Future<void> markOnlineViaBackend() async {
    if (_syncInProgress) return;
    _syncInProgress = true;

    try {
      final token = await _preferences.getToken();
      if (token.isEmpty) return;

      final appUrl = await _preferences.getAppUrl();
      final uri = Uri.parse('$appUrl${Constant.SEND_LOCATION}');

      final storage = await SharedPreferences.getInstance();
      final coordinates = await _resolveCoordinates(storage);
      final latitude = coordinates['latitude'] ?? 0.0;
      final longitude = coordinates['longitude'] ?? 0.0;

        final response = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: {
              'latitude': latitude.toString(),
              'longitude': longitude.toString(),
            },
          )
          .timeout(const Duration(seconds: 6));

      if (kDebugMode) {
        if (response.statusCode == 200) {
          debugPrint('✅ PresenceSync: server location ping success');
        } else {
          debugPrint('⚠️ PresenceSync: location ping failed ${response.statusCode}');
        }
      }
    } on TimeoutException {
      if (kDebugMode) debugPrint('⚠️ PresenceSync: location ping timeout');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ PresenceSync: location ping error $e');
    } finally {
      _syncInProgress = false;
    }
  }
}
