import 'package:clipper2/clipper2.dart';

import 'lat_lng.dart';
import 'projection.dart';
import 'wkt.dart';

class Claim {
  final String id;
  final String ownerId;
  final PathsD geometry;
  final double areaM2;

  const Claim({
    required this.id,
    required this.ownerId,
    required this.geometry,
    required this.areaM2,
  });

  Claim copyWith({PathsD? geometry, double? areaM2}) => Claim(
    id: id,
    ownerId: ownerId,
    geometry: geometry ?? this.geometry,
    areaM2: areaM2 ?? this.areaM2,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Claim && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class TerritoryEngine {
  TerritoryEngine._();

  static const double sliverAreaM2 = 50.0;

  static const int _precisionM = 3;

  static const double _areaEpsilonM2 = 0.001;

  static PathsD? buildTerritory(List<LatLng> track, LatLng ref) {
    if (track.length < 3) return null;

    final ring = track.map((p) => Projection.project(p, ref)).toList();
    if (ring.length > 1 && ring.first == ring.last) ring.removeLast();
    if (ring.length < 3) return null;

    try {
      final repaired = Clipper.unionD(
        subject: <PathD>[ring],
        clip: <PathD>[],
        fillRule: FillRule.nonZero,
        precision: _precisionM,
      );
      return repaired.isEmpty || repaired.area.abs() < _areaEpsilonM2
          ? null
          : repaired;
    } catch (_) {
      return null;
    }
  }

  static PathsD? buildTerritoryGeographic(List<LatLng> track, LatLng ref) {
    final metres = buildTerritory(track, ref);
    return metres == null ? null : toGeographic(metres, ref);
  }

  static PathsD toGeographic(PathsD metres, LatLng ref) => metres
      .map(
        (ring) => ring.map((c) {
          final p = Projection.unproject(c, ref);
          return PointD(p.longitude, p.latitude);
        }).toList(),
      )
      .toList();

  static PathsD toMetres(PathsD geographic, LatLng ref) => geographic
      .map(
        (ring) =>
            ring.map((c) => Projection.project(LatLng(c.y, c.x), ref)).toList(),
      )
      .toList();

  static LatLng referenceOf(PathsD geographic) {
    var twiceArea = 0.0;
    var cx = 0.0;
    var cy = 0.0;

    for (final ring in geographic) {
      for (var i = 0; i < ring.length; i++) {
        final a = ring[i];
        final b = ring[(i + 1) % ring.length];
        final cross = a.x * b.y - b.x * a.y;
        twiceArea += cross;
        cx += (a.x + b.x) * cross;
        cy += (a.y + b.y) * cross;
      }
    }

    if (twiceArea.abs() < 1e-12) {
      var n = 0;
      var sx = 0.0, sy = 0.0;
      for (final ring in geographic) {
        for (final p in ring) {
          sx += p.x;
          sy += p.y;
          n++;
        }
      }
      return n == 0 ? const LatLng(0, 0) : LatLng(sy / n, sx / n);
    }

    final factor = 1 / (3 * twiceArea);
    return LatLng(cy * factor, cx * factor);
  }

  static double areaM2(PathsD geographic) {
    if (geographic.isEmpty) return 0.0;
    return toMetres(geographic, referenceOf(geographic)).area.abs();
  }

  static List<Claim> resolveClaim(PathsD claim, List<Claim> existing) {
    if (claim.isEmpty || existing.isEmpty) return existing;

    final ref = referenceOf(claim);
    final claimM = toMetres(claim, ref);
    final survivors = <Claim>[];

    for (final t in existing) {
      final defenderM = toMetres(t.geometry, ref);
      final before = defenderM.area.abs();

      PathsD leftM;
      try {
        leftM = Clipper.differenceD(
          subject: defenderM,
          clip: claimM,
          fillRule: FillRule.nonZero,
          precision: _precisionM,
        );
      } catch (_) {
        survivors.add(t);
        continue;
      }

      final after = leftM.area.abs();

      if ((before - after).abs() < _areaEpsilonM2) {
        survivors.add(t);
        continue;
      }

      if (leftM.isEmpty || after < sliverAreaM2) continue;

      survivors.add(
        t.copyWith(geometry: toGeographic(leftM, ref), areaM2: after),
      );
    }

    return survivors;
  }

  static PathsD mergeOwn(PathsD claim, List<Claim> own) {
    if (own.isEmpty) return claim;

    final ref = referenceOf(claim);
    var acc = toMetres(claim, ref);

    for (final t in own) {
      try {
        acc = Clipper.unionD(
          subject: acc,
          clip: toMetres(t.geometry, ref),
          fillRule: FillRule.nonZero,
          precision: _precisionM,
        );
      } catch (_) {
      }
    }
    return toGeographic(acc, ref);
  }

  static PathsD intersect(PathsD a, PathsD b) {
    if (a.isEmpty || b.isEmpty) return <PathD>[];
    final ref = referenceOf(a);
    try {
      final both = Clipper.intersectD(
        subject: toMetres(a, ref),
        clip: toMetres(b, ref),
        fillRule: FillRule.nonZero,
        precision: _precisionM,
      );
      if (both.isEmpty || both.area.abs() < sliverAreaM2) return <PathD>[];
      return toGeographic(both, ref);
    } catch (_) {
      return areaM2(a) <= areaM2(b) ? a : b;
    }
  }

  static ({double minLat, double maxLat, double minLng, double maxLng})?
  boundsOf(PathsD geographic) {
    double? minLat, maxLat, minLng, maxLng;
    for (final ring in geographic) {
      for (final p in ring) {
        minLat = minLat == null || p.y < minLat ? p.y : minLat;
        maxLat = maxLat == null || p.y > maxLat ? p.y : maxLat;
        minLng = minLng == null || p.x < minLng ? p.x : minLng;
        maxLng = maxLng == null || p.x > maxLng ? p.x : maxLng;
      }
    }
    if (minLat == null) return null;
    return (minLat: minLat, maxLat: maxLat!, minLng: minLng!, maxLng: maxLng!);
  }

  static String toWkt(PathsD g) => writeWkt(g);

  static PathsD? fromWkt(String wkt) => readWkt(wkt);
}
