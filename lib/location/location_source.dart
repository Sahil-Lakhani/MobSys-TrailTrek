import '../geo/lat_lng.dart';

/// One accepted position report.
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

/// Where positions come from.
///
/// Two implementations sit behind this: real GPS, and GPX playback. The replay source is what
/// makes the geometry testable indoors at 10x speed — debugging polygon clipping by walking
/// around a car park is not a workable loop.
abstract class LocationSource {
  /// Begins producing fixes. The stream closes when the source is exhausted or stopped.
  Stream<Fix> start();

  Future<void> stop();

  static const double maxAccuracyM = 20;
  static const double maxSpeedMs = 8;

  /// Gate fixes before they ever reach the track. A single 60-metre outlier turns a neat loop
  /// into a spike that swallows a whole city block.
  static bool accept(Fix fix) =>
      fix.accuracyM > 0 &&
      fix.accuracyM < maxAccuracyM &&
      fix.speedMs < maxSpeedMs;
}
