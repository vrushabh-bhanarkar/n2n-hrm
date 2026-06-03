import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationStatus {
  Future<Position> determinePosition(String workspace) async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // 1. Check hardware availability
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Future.error('Please enable your location, it seems to be turned off.');
      }

      // 2. Validate application permission scopes
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return Future.error(
            'Location permissions are permanently denied. Please enable them in system settings and try again.');
      }

      // 3. Define target location settings (Optimized for instantaneous fetch)
      // Removed distanceFilter so it doesn't block updates when stationary
      final LocationSettings locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7), // Snappy timeout before graceful fallback
        forceLocationManager: false, // Set to true if Google Play Services are missing
      );

      try {
        // Attempt an absolute precise location read
        Position currentPos = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        );
        
        // Final guard rail against corrupted mock locations or hardware drops
        if (currentPos.latitude == 0.0 && currentPos.longitude == 0.0) {
          throw const FormatException('Hardware returned empty coordinates.');
        }
        
        return currentPos;
      } on TimeoutException catch (_) {
        print('[LocationStatus] Precise lock timed out. Trying last known hardware coordinates...');
        
        // 4. Graceful Fallback: Fetch last known location instead of throwing 0.0, 0.0
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        
        if (lastKnown != null && lastKnown.latitude != 0.0 && lastKnown.longitude != 0.0) {
          print('[LocationStatus] Successfully recovered last known position: ${lastKnown.latitude}, ${lastKnown.longitude}');
          return lastKnown;
        }
        
        return Future.error('Unable to capture location lock. Please move to an open area or re-verify GPS signal.');
      } catch (e) {
        print('[LocationStatus] Direct fetch error: ${e.toString()}');
        return Future.error('Location could not be verified. Please check GPS signal stability.');
      }
    } catch (e) {
      print('[LocationStatus] Core Exception: ${e.toString()}');
      return Future.error('Location tracking error occurred.');
    }
  }
}