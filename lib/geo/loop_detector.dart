import 'lat_lng.dart';
import 'projection.dart';

class LoopDetector {
  LoopDetector._();

  static const int minPoints = 20;
  static const double minTravelM = 200.0;
  static const double closeRadiusM = 30.0;

  static const double _progressHorizonM = 300.0;

  static bool isClosed(List<LatLng> track, {double? travelledM}) {
    if (track.length < minPoints) return false;
    final travelled = travelledM ?? Projection.pathLength(track);
    if (travelled <= minTravelM) return false;
    return Projection.haversine(track.first, track.last) < closeRadiusM;
  }

  static double closureProgress(List<LatLng> track, {double? travelledM}) {
    if (track.length < 2) return 0.0;
    final travelled = travelledM ?? Projection.pathLength(track);
    if (travelled <= minTravelM) {
      return (travelled / minTravelM).clamp(0.0, 1.0);
    }
    final gap = Projection.haversine(track.first, track.last);
    return (1.0 - (gap / _progressHorizonM)).clamp(0.0, 1.0);
  }

  static double distanceToStart(List<LatLng> track) =>
      track.length < 2 ? 0.0 : Projection.haversine(track.first, track.last);
}
