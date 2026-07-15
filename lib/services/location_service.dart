import 'package:geolocator/geolocator.dart';

/// Encapsule la récupération de la position GPS via `geolocator`.
/// Ne lance jamais d'exception : renvoie `null` si permission refusée,
/// service coupé, ou délai dépassé. La géoloc est un bonus, jamais bloquant.
class LocationService {
  static const _timeout = Duration(seconds: 6);

  Future<({double latitude, double longitude})?> getCurrentPosition() async {
    try {
      // Sur le web, isLocationServiceEnabled() renvoie toujours true
      // (pas de notion de "service de localisation" séparée du navigateur).
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        ),
      ).timeout(_timeout);

      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
    }
  }
}
