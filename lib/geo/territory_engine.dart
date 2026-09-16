import 'package:clipper2/clipper2.dart';

import 'lat_lng.dart';
import 'projection.dart';
import 'wkt.dart';

/// One owned patch of ground.
///
/// [geometry] is stored in *geographic* coordinates (x = longitude, y = latitude) so it
/// survives being reloaded next to territories claimed from a different reference point.
/// Anything that needs an area or a boolean operation converts to metres first.
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

  /// Anything smaller than this is GPS noise along a shared edge, not land worth keeping.
  static const double sliverAreaM2 = 50.0;

  /// Decimal places clipper rounds metre coordinates to. Millimetres is far finer than GPS
  /// resolves, and keeps the scaled integers comfortably inside 64 bits.
  static const int _precisionM = 3;

  /// Areas closer than this are the same area; used to tell "the claim missed" from
  /// "the claim took something".
  static const double _areaEpsilonM2 = 0.001;

  // ---------------------------------------------------------------------- building

  /// Turn a run track into a polygon, in metres relative to [ref].
  ///
  /// GPS drift routinely produces self-intersecting rings, which are not valid polygons and
  /// cannot take part in boolean operations. Running the ring through a union re-nodes it and
  /// hands back a clean result — the same repair JTS spells `buffer(0)`.
  ///
  /// The result may hold several rings: a figure-of-eight route splits into two lobes. Callers
  /// must treat it as a set of rings, never as a single polygon.
  static PathsD? buildTerritory(List<LatLng> track, LatLng ref) {
    if (track.length < 3) return null;

    final ring = track.map((p) => Projection.project(p, ref)).toList();
    // WKT closes rings explicitly; clipper leaves closure implicit.
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

  /// Build straight into geographic coordinates, ready to store.
  static PathsD? buildTerritoryGeographic(List<LatLng> track, LatLng ref) {
    final metres = buildTerritory(track, ref);
    return metres == null ? null : toGeographic(metres, ref);
  }

  // ------------------------------------------------------------------- conversions

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

  /// Reference point to project a geometry about: its own centroid.
  ///
  /// Area-weighted, and signed, so holes pull the centroid the way they should.
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
      // Degenerate (zero-area) input: fall back to the mean vertex.
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

  /// Square metres of a geographic geometry.
  static double areaM2(PathsD geographic) {
    if (geographic.isEmpty) return 0.0;
    return toMetres(geographic, referenceOf(geographic)).area.abs();
  }

  // ------------------------------------------------------------------------ claims

  /// Apply a fresh claim to the territories that already exist.
  ///
  /// Everything is projected into one shared metre frame first — differencing two geometries
  /// that were each projected about their own reference point would shear them relative to
  /// each other.
  ///
  /// Untouched territories pass through unchanged. Overlapped ones lose the overlap. A
  /// territory reduced to slivers disappears entirely.
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
        // A geometry that will not clip keeps its ground rather than vanishing.
        survivors.add(t);
        continue;
      }

      final after = leftM.area.abs();

      // Nothing was taken: keep the original object so identity and stored WKT are untouched.
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

  /// Fold a new claim into the same owner's existing ground so one runner's territory reads as
  /// a single holding rather than a pile of overlapping loops.
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
        // A geometry that will not union is left out rather than losing the whole merge.
      }
    }
    return toGeographic(acc, ref);
  }

  // ------------------------------------------------------------------ serialisation

  static String toWkt(PathsD g) => writeWkt(g);

  static PathsD? fromWkt(String wkt) => readWkt(wkt);
}
