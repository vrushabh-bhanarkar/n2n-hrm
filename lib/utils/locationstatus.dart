import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationStatus {
  Future<Position> determinePosition(String workspace) async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled don't continue
        // accessing the position and request users of the
        // App to enable the location services.
        return Future.error(
            'Please enable your location, it seems to be turned off.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied, next time you could try
          // requesting permissions again (this is also where
          // Android's shouldShowRequestPermissionRationale
          // returned true. According to Android guidelines
          // your App should show an explanatory UI now.
          return Future.error('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        return Future.error(
            'Location permissions are permanently denied, we cannot request permissions. Please give permission and try again.');
      }

      /*if (workspace == "1") {
        return Position(
            longitude: 10.0,
            latitude: 10.0,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0);
      }*/

      final LocationSettings locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
        distanceFilter: 100,
      );

      try {
        return await Geolocator.getCurrentPosition(
            locationSettings: locationSettings);
      } on TimeoutException {
        return Future.error(
            'Location fix timed out. Please wait a moment, then try again after enabling GPS and moving to an open area.');
      } catch (e) {
        print(e.toString());
        return Future.error(
            'Location can not be found. Please check GPS, permissions, and try again.');
      }
    } catch (e) {
      print(e.toString());
      return Future.error(
          'Location can not be found. Please check GPS, permissions, and try again.');
    }
  }
}
