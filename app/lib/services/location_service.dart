import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Great-circle distance in kilometers between two points (haversine).
/// Top-level helper for client-side nearby filtering without a plugin.
double haversineKm(double fromLat, double fromLng, double toLat, double toLng) {
  const r = 6371.0; // Earth radius in km
  final dLat = _rad(toLat - fromLat);
  final dLng = _rad(toLng - fromLng);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(fromLat)) *
          math.cos(_rad(toLat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _rad(double deg) => deg * math.pi / 180;

/// Device location via geolocator; used with flutter_map (OpenStreetMap).
class LocationService {
  /// Returns the current position, requesting permission first.
  /// Throws [StateError] when permission is denied or services are off.
  Future<Position> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location services are disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Location permission denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
          'Location permission permanently denied — enable it in settings');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Great-circle distance in kilometers between two points.
  double distanceKm(
      double fromLat, double fromLng, double toLat, double toLng) {
    return Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng) / 1000.0;
  }
}
