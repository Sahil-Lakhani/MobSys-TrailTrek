import 'lat_lng.dart';
import 'projection.dart';

/// Decides whether a track *could* be closed into a loop worth claiming.
///
/// Three conditions, all of them necessary:
///  - enough fixes that the shape is not GPS noise,
///  - the runner actually went somewhere (otherwise standing still "closes" instantly),
///  - and is back within [closeRadiusM] of the start.
///
/// Answering yes does not end the run. The runner may carry on past the start to take in
/// ground on the far side; the loop is only closed when they end the run while this holds.
class LoopDetector {
  LoopDetector._();

  static const int minPoints = 20;
  static const double minTravelM = 200.0;

  /// How near the start the runner must be when they end the run for it to claim ground.
  /// Wide enough that nobody has to hunt for the exact spot they set off from.
  static const double closeRadiusM = 69.0;

  /// Beyond this distance from home there is nothing useful to show on the progress hint.
  static const double _progressHorizonM = 300.0;

  /// [travelledM] lets a caller that already knows the distance say so. Recomputing it walks
  /// the whole track, and a live run asks this question on every fix — which turns an O(n)
  /// answer into O(n^2) work over the run.
  static bool isClosed(List<LatLng> track, {double? travelledM}) {
    if (track.length < minPoints) return false;
    final travelled = travelledM ?? Projection.pathLength(track);
    if (travelled <= minTravelM) return false;
    return Projection.haversine(track.first, track.last) < closeRadiusM;
  }

  /// How close the runner is to closing, 0..1. Drives the "return to start" hint so the UI can
  /// nudge before the loop actually snaps shut.
  static double closureProgress(List<LatLng> track, {double? travelledM}) {
    if (track.length < 2) return 0.0;
    final travelled = travelledM ?? Projection.pathLength(track);
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
