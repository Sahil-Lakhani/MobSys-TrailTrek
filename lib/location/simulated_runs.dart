import 'dart:math' as math;

import 'package:clipper2/clipper2.dart';

import '../geo/lat_lng.dart';
import '../geo/projection.dart';
import '../geo/territory_engine.dart';
import 'replay_source.dart';

class PlannedRival {
  const PlannedRival({
    required this.ownerId,
    required this.ownerName,
    required this.geometry,
  });

  final String ownerId;
  final String ownerName;

  final PathsD geometry;
}

class SimulatedRun {
  const SimulatedRun({required this.points, required this.description});

  final List<GpxPoint> points;
  final String description;
}

abstract final class SimulatedRuns {
  static const double _stepM = 8;

  static const double _paceMs = 3.2;

  static const double captureSideM = 160;

  static SimulatedRun capture({
    required LatLng runner,
    required List<PathsD> existing,
  }) {
    const distances = [300.0, 500.0, 700.0, 900.0, 1200.0];
    LatLng? chosen;
    for (final distance in distances) {
      for (var bearing = 0.0; bearing < 360; bearing += 45) {
        final centre = _offset(runner, bearing, distance);
        final square = _squareAround(centre, captureSideM);
        final geometry = TerritoryEngine.buildTerritoryGeographic(
          square,
          centre,
        );
        if (geometry == null) continue;
        final clear = existing.every(
          (g) => TerritoryEngine.intersect(g, geometry).isEmpty,
        );
        if (clear) {
          chosen = centre;
          break;
        }
      }
      if (chosen != null) break;
    }
    chosen ??= _offset(runner, 0, distances.first);

    return SimulatedRun(
      points: _asRun(_squareAround(chosen, captureSideM)),
      description: 'Test run: capturing new ground',
    );
  }

  static SimulatedRun? steal({
    required LatLng runner,
    required List<PlannedRival> rivals,
  }) {
    PlannedRival? nearest;
    var nearestM = double.infinity;
    for (final rival in rivals) {
      if (rival.geometry.isEmpty) continue;
      final metres = Projection.haversine(
        runner,
        TerritoryEngine.referenceOf(rival.geometry),
      );
      if (metres < nearestM) {
        nearestM = metres;
        nearest = rival;
      }
    }
    if (nearest == null) return null;

    final b = TerritoryEngine.boundsOf(nearest.geometry)!;
    final midLng = (b.minLng + b.maxLng) / 2;
    final centreLat = (b.minLat + b.maxLat) / 2;

    const padM = 70.0;
    final padLat = padM / Projection.metresPerDegreeLat;
    final padLng = padM / Projection.metresPerDegreeLon(centreLat);

    final corners = [
      LatLng(b.minLat - padLat, b.minLng - padLng),
      LatLng(b.minLat - padLat, midLng),
      LatLng(b.maxLat + padLat, midLng),
      LatLng(b.maxLat + padLat, b.minLng - padLng),
    ];

    return SimulatedRun(
      points: _asRun(_densify(corners)),
      description: 'Test run: stealing from ${nearest.ownerName}',
    );
  }

  static List<LatLng> _squareAround(LatLng centre, double sideM) {
    final half = sideM / 2;
    LatLng at(double e, double n) => Projection.unproject(PointD(e, n), centre);
    return _densify([
      at(-half, -half),
      at(half, -half),
      at(half, half),
      at(-half, half),
    ]);
  }

  static List<LatLng> _densify(List<LatLng> corners) {
    final out = <LatLng>[];
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      final length = Projection.haversine(a, b);
      final steps = math.max(1, (length / _stepM).ceil());
      for (var s = 0; s < steps; s++) {
        final t = s / steps;
        out.add(
          LatLng(
            a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t,
          ),
        );
      }
    }
    out.add(corners.first);
    return out;
  }

  static List<GpxPoint> _asRun(List<LatLng> ring) {
    var clock = DateTime.now();
    final out = <GpxPoint>[];
    for (var i = 0; i < ring.length; i++) {
      if (i > 0) {
        final metres = Projection.haversine(ring[i - 1], ring[i]);
        clock = clock.add(
          Duration(milliseconds: (metres / _paceMs * 1000).round()),
        );
      }
      final t = ring.length < 2 ? 0.0 : i / (ring.length - 1);
      out.add(
        GpxPoint(
          point: ring[i],
          elevationM: 300 + 18 * math.sin(math.pi * t),
          time: clock,
        ),
      );
    }
    return out;
  }

  static LatLng _offset(LatLng from, double bearingDeg, double metres) {
    final rad = bearingDeg * math.pi / 180;
    return LatLng(
      from.latitude + math.cos(rad) * metres / Projection.metresPerDegreeLat,
      from.longitude +
          math.sin(rad) * metres / Projection.metresPerDegreeLon(from.latitude),
    );
  }
}
