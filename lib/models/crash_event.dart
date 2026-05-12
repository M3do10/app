import 'package:geolocator/geolocator.dart';

class CrashEvent {
  CrashEvent({
    required this.id,
    required this.detectedAt,
    required this.peakMagnitudeMps2,
    this.peakGyroRadS,
    this.position,
    this.locationError,
  });

  final String id;
  final DateTime detectedAt;
  final double peakMagnitudeMps2;
  final double? peakGyroRadS;
  final Position? position;
  final String? locationError;

  double get peakG => peakMagnitudeMps2 / 9.80665;

  bool get hasFix =>
      position != null &&
      position!.latitude != 0 &&
      position!.longitude != 0;
}
