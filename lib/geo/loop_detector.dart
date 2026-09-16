import 'lat_lng.dart';
import 'projection.dart';

/// Decides when a track has become a closed loop worth claiming.
///
/// Three conditions, all of them necessary:
///  - enough fixes that the shape is not GPS noise,
///  - the runner actually went somewhere (otherwise standing still "closes" instantly),
///  - and came back to within a GPS-plausible radius of the start.
class LoopDetector {
  LoopDetector._();

  static const int minPoints = 20;
  static const double minTravelM = 200.0;
  static const double closeRadiusM = 30.0;

  /// Beyond this distance from home there is nothing useful to show on the progress hint.
  static const double _progressHorizonM = 300.0;

  static bool isClosed(List<LatLng> track) {
    if (track.length < minPoints) return false;
    if (Projection.pathLength(track) <= minTravelM) return false;
    return Projection.haversine(track.first, track.last) < closeRadiusM;
  }

  /// How close the runner is to closing, 0..1. Drives the "return to start" hint so the UI can
  /// nudge before the loop actually snaps shut.
  static double closureProgress(List<LatLng> track) {
    if (track.length < 2) return 0.0;
    final travelled = Projection.pathLength(track);
    if (travelled <= minTravelM) {
      return (travelled / minTravelM).clamp(0.0, 1.0);
    }
    final gap = Projection.haversine(track.first, track.last);
    return (1.0 - (gap / _progressHorizonM)).clamp(0.0, 1.0);
  }

  /// Metres from the current position back to the start of the loop.
  static double distanceToStart(List<LatLng> track) =>
      track.length < 2 ? 0.0 : Projection.haversine(track.first, track.last);
}
