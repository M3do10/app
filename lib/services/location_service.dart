import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Future<bool> ensureLocationReady() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var perm = await Permission.locationWhenInUse.status;
    if (perm.isDenied) {
      perm = await Permission.locationWhenInUse.request();
    }
    if (perm.isPermanentlyDenied || perm.isDenied) return false;

    final g = await Geolocator.checkPermission();
    if (g == LocationPermission.denied) {
      final r = await Geolocator.requestPermission();
      if (r == LocationPermission.denied ||
          r == LocationPermission.deniedForever) {
        return false;
      }
    } else if (g == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  static Future<(Position?, String?)> captureHighAccuracy() async {
    try {
      final ok = await ensureLocationReady();
      if (!ok) return (null, 'Location permission or services unavailable.');
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return (p, null);
    } catch (e) {
      return (null, e.toString());
    }
  }
}
