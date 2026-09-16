import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/geo/projection.dart';
import 'package:clipper2/clipper2.dart';

/// Shared fixtures. Tracks are authored in metres and converted to lat/lng, because a square
/// expressed in degrees is not a square on the ground.
class GeoTestSupport {
  static const ref = LatLng(50.7217, 10.4483);

  static LatLng point(double eastM, double northM, [LatLng reference = ref]) =>
      Projection.unproject(PointD(eastM, northM), reference);

  /// A closed square of the given side, sampled densely enough to look like a real track.
  static List<LatLng> square(
    double sideM, {
    int perEdge = 8,
    LatLng reference = ref,
  }) {
    final corners = <List<double>>[
      [0, 0],
      [sideM, 0],
      [sideM, sideM],
      [0, sideM],
    ];
    final out = <LatLng>[];
    for (var i = 0; i < corners.length; i++) {
      final start = corners[i];
      final end = corners[(i + 1) % corners.length];
      for (var s = 0; s < perEdge; s++) {
        final t = s / perEdge;
        out.add(
          point(
            start[0] + (end[0] - start[0]) * t,
            start[1] + (end[1] - start[1]) * t,
            reference,
          ),
        );
      }
    }
    out.add(out.first);
    return out;
  }

  /// Two lobes crossing in the middle: the shape GPS drift produces and JTS rejects.
  static List<LatLng> figureEight({
    double sizeM = 100.0,
    LatLng reference = ref,
  }) => [
    point(0, 0, reference),
    point(sizeM, 0, reference),
    point(0, sizeM, reference),
    point(sizeM, sizeM, reference),
    point(0, 0, reference),
  ];

  /// Translate a track by a metre offset about [ref]. Used to build attackers that overlap a
  /// defender by a known, exactly calculable amount.
  static List<LatLng> shifted(
    List<LatLng> track,
    double eastM,
    double northM,
  ) => track.map((p) {
    final c = Projection.project(p, ref);
    return point(c.x + eastM, c.y + northM);
  }).toList();
}
