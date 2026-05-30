import 'package:cnattendance/utils/constant.dart';
import 'package:geolocator/geolocator.dart';

class OfficeGeofence {
  static bool hasAcceptableAccuracy(Position position) {
    return position.accuracy > 0 &&
        position.accuracy <= Constant.OFFICE_LOCATION_MAX_ACCURACY_METERS;
  }

  static double distanceFromOfficeMeters(double latitude, double longitude) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      Constant.OFFICE_LATITUDE,
      Constant.OFFICE_LONGITUDE,
    );
  }

  static bool isWithinOfficeRadius(double latitude, double longitude) {
    return distanceFromOfficeMeters(latitude, longitude) <=
        Constant.OFFICE_GEOFENCE_RADIUS_METERS;
  }

  static bool isAcceptableOfficePosition(Position position) {
    return hasAcceptableAccuracy(position) &&
        isWithinOfficeRadius(position.latitude, position.longitude);
  }
}