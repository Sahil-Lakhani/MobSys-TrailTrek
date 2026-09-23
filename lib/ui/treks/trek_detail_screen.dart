import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/trail_repository.dart';
import '../../geo/projection.dart' as geo;
import '../tracking/tracking_controller.dart';
import '../tracking/tracking_map.dart' show osmLand, toMap;

/// One trail, drawn.
///
/// The waypoint arrow points at the trailhead and only appears when the device has a compass —
/// an arrow that cannot turn is worse than no arrow.
class TrekDetailScreen extends ConsumerWidget {
  const TrekDetailScreen({required this.trail, super.key});

  final TrailListing trail;

  static String _km(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingControllerProvider);
    final here = state.currentFix?.point ?? state.origin;

    final bounds = LatLngBounds.fromPoints(trail.path.map(toMap).toList());

    return Scaffold(
      appBar: AppBar(title: Text(trail.name)),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                // Tiles arrive a moment after the map does, and flutter_map paints the gap
                // in its default grey — a hard block that reads as a rendering fault. This
                // is OpenStreetMap's own land tone, so a tile still loading is a shade of
                // the map rather than a hole in it.
                backgroundColor: osmLand,
                // Fitting from the camera constraint rather than after layout: the same
                // before-layout trap that lands `fitCamera` on zoom 0 when run too early.
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(40),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'de.hsm.claimtrek',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trail.path.map(toMap).toList(),
                      color: Colors.deepPurple,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: toMap(trail.path.first),
                      width: 22,
                      height: 22,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (state.availability.compass &&
                      state.headingDeg != null &&
                      here != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: CustomPaint(
                        size: const Size(52, 52),
                        painter: WaypointArrowPainter(
                          bearingDeg:
                              geo.Projection.bearing(here, trail.path.first) -
                              state.headingDeg!,
                          colour: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_km(trail.lengthM)} long',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${_km(trail.distanceM)} to the trailhead'),
                        Text(
                          trail.kind,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An arrow pointing at the trailhead, relative to the way the phone is facing.
///
/// Paints are built once per instance rather than per frame — allocating in `paint` is what
/// turns a smooth needle into a stuttering one.
class WaypointArrowPainter extends CustomPainter {
  WaypointArrowPainter({required this.bearingDeg, required Color colour})
    : _fill = Paint()
        ..color = colour
        ..style = PaintingStyle.fill,
      _ring = Paint()
        ..color = colour.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

  final double bearingDeg;
  final Paint _fill;
  final Paint _ring;
  final Path _arrow = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;

    canvas.drawCircle(centre, radius, _ring);

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(bearingDeg * math.pi / 180.0);

    _arrow
      ..reset()
      ..moveTo(0, -radius * 0.72)
      ..lineTo(radius * 0.45, radius * 0.6)
      ..lineTo(0, radius * 0.28)
      ..lineTo(-radius * 0.45, radius * 0.6)
      ..close();

    canvas.drawPath(_arrow, _fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(WaypointArrowPainter oldDelegate) =>
      oldDelegate.bearingDeg != bearingDeg;
}
