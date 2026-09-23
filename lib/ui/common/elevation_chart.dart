import 'package:flutter/material.dart';

import '../../data/local/elevation_codec.dart';

/// The profile reduced to canvas coordinates, kept apart from the painter so the arithmetic
/// can be tested without pumping a widget or rasterising anything.
///
/// Works in raw canvas space: the caller insets for labels before handing over a [Size].
class ElevationChartGeometry {
  ElevationChartGeometry._({
    required this.points,
    required this.minAltitudeM,
    required this.maxAltitudeM,
    required this.totalDistanceM,
  });

  factory ElevationChartGeometry.fromSamples(
    List<ElevationSample> samples,
    Size size,
  ) {
    if (samples.length < 2) {
      return ElevationChartGeometry._(
        points: const [],
        minAltitudeM: 0,
        maxAltitudeM: 0,
        totalDistanceM: 0,
      );
    }

    var minAltitude = samples.first.altitudeM;
    var maxAltitude = samples.first.altitudeM;
    for (final s in samples) {
      if (s.altitudeM < minAltitude) minAltitude = s.altitudeM;
      if (s.altitudeM > maxAltitude) maxAltitude = s.altitudeM;
    }

    final totalDistance = samples.last.distanceM - samples.first.distanceM;
    final relief = maxAltitude - minAltitude;

    // Both spans can legitimately be zero — a lap of a flat track, or a stationary runner with
    // a drifting sensor. Normalising by either without checking yields NaN offsets, and a
    // canvas given NaN draws nothing at all rather than complaining.
    final flat = relief.abs() < 1e-9;
    final stationary = totalDistance.abs() < 1e-9;

    final points = <Offset>[];
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];

      final xFraction = stationary
          // Spread evenly instead: the samples are real, only their spacing is unknowable.
          ? (samples.length == 1 ? 0.0 : i / (samples.length - 1))
          : (s.distanceM - samples.first.distanceM) / totalDistance;

      // A level run sits on the centre line. Pinning it to the floor or the ceiling would
      // read as a a cliff at one end of an otherwise flat course.
      final yFraction = flat ? 0.5 : (s.altitudeM - minAltitude) / relief;

      points.add(
        // y is inverted: canvas y grows downward, and the summit belongs at the top.
        Offset(xFraction * size.width, (1 - yFraction) * size.height),
      );
    }

    return ElevationChartGeometry._(
      points: points,
      minAltitudeM: minAltitude,
      maxAltitudeM: maxAltitude,
      totalDistanceM: totalDistance,
    );
  }

  final List<Offset> points;
  final double minAltitudeM;
  final double maxAltitudeM;
  final double totalDistanceM;

  bool get isDrawable => points.length >= 2;
}

/// A run's elevation profile, drawn rather than assembled from widgets.
///
/// Renders nothing when there is too little to plot — a phone with no barometer and no GPS
/// height should hide the feature, not present an empty frame. Same rule the stats counter
/// follows for its optional readings.
class ElevationChart extends StatelessWidget {
  const ElevationChart({required this.samples, this.height = 120, super.key});

  final List<ElevationSample> samples;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    // Read once here rather than inside the painter, so the axis labels are real widgets —
    // selectable, scalable with the platform text size, and findable in a test.
    final geometry = ElevationChartGeometry.fromSamples(
      samples,
      const Size(1, 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${geometry.maxAltitudeM.round()} m', style: labelStyle),
                    Text('${geometry.minAltitudeM.round()} m', style: labelStyle),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CustomPaint(
                  painter: _ElevationChartPainter(
                    samples: samples,
                    line: scheme.primary,
                    fill: scheme.primary.withValues(alpha: 0.22),
                    baseline: scheme.outlineVariant,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 50),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: labelStyle),
              Text(_formatDistance(geometry.totalDistanceM), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatDistance(double metres) => metres >= 1000
    ? '${(metres / 1000).toStringAsFixed(1)} km'
    : '${metres.round()} m';

class _ElevationChartPainter extends CustomPainter {
  _ElevationChartPainter({
    required this.samples,
    required this.line,
    required this.fill,
    required this.baseline,
  });

  final List<ElevationSample> samples;
  final Color line;
  final Color fill;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset the top so the peak's stroke is not clipped in half by the canvas edge.
    final plot = Size(size.width, size.height - 2);
    final geometry = ElevationChartGeometry.fromSamples(samples, plot);
    if (!geometry.isDrawable) return;

    final points = geometry.points
        .map((p) => Offset(p.dx, p.dy + 1))
        .toList(growable: false);

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    final profile = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      profile.lineTo(p.dx, p.dy);
    }

    final beneath = Path.from(profile)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(beneath, Paint()..color = fill);

    canvas.drawPath(
      profile,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ElevationChartPainter old) =>
      !identical(old.samples, samples) ||
      old.line != line ||
      old.fill != fill ||
      old.baseline != baseline;
}
