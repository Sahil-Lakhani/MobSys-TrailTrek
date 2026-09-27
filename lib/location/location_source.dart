import '../geo/lat_lng.dart';

class Fix {
  final LatLng point;
  final double accuracyM;
  final double speedMs;
  final double? altitudeM;
  final int timestampMs;

  const Fix({
    required this.point,
    required this.accuracyM,
    required this.speedMs,
    this.altitudeM,
    required this.timestampMs,
  });
}

abstract class LocationSource {
  Stream<Fix> start();

  Future<void> stop();

  static const double maxAccuracyM = 20;
  static const double maxSpeedMs = 8;

  static bool accept(Fix fix) =>
      fix.accuracyM > 0 &&
      fix.accuracyM < maxAccuracyM &&
      fix.speedMs < maxSpeedMs;
}
