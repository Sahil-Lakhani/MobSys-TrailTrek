import 'package:claimtrek/data/local/elevation_codec.dart';
import 'package:claimtrek/ui/common/elevation_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _canvas = Size(200, 100);

List<ElevationSample> _ramp() => const [
  ElevationSample(distanceM: 0, altitudeM: 100),
  ElevationSample(distanceM: 500, altitudeM: 150),
  ElevationSample(distanceM: 1000, altitudeM: 200),
];

void main() {
  group('geometry', () {
    test('the profile spans the full canvas width', () {
      final g = ElevationChartGeometry.fromSamples(_ramp(), _canvas);

      expect(g.isDrawable, isTrue);
      expect(g.points, hasLength(3));
      expect(g.points.first.dx, closeTo(0, 0.001));
      expect(g.points.last.dx, closeTo(_canvas.width, 0.001));
      // Halfway along the run is halfway across the chart.
      expect(g.points[1].dx, closeTo(100, 0.001));
    });

    test('higher ground draws nearer the top', () {
      // Canvas y grows downward, so the summit must be the SMALLEST y. Getting this backwards
      // renders every hill as a valley and still looks plausible at a glance.
      final g = ElevationChartGeometry.fromSamples(_ramp(), _canvas);

      expect(g.points.first.dy, closeTo(_canvas.height, 0.001));
      expect(g.points.last.dy, closeTo(0, 0.001));
      expect(g.points[1].dy, closeTo(50, 0.001));
    });

    test('min and max altitude are reported for the axis labels', () {
      final g = ElevationChartGeometry.fromSamples(_ramp(), _canvas);
      expect(g.minAltitudeM, closeTo(100, 1e-9));
      expect(g.maxAltitudeM, closeTo(200, 1e-9));
      expect(g.totalDistanceM, closeTo(1000, 1e-9));
    });

    test('a flat run draws a level line instead of dividing by zero', () {
      // A lap of a track has no relief at all. Normalising by (max - min) here is a divide by
      // zero, and NaN offsets make the canvas silently draw nothing.
      const flat = [
        ElevationSample(distanceM: 0, altitudeM: 42),
        ElevationSample(distanceM: 400, altitudeM: 42),
      ];

      final g = ElevationChartGeometry.fromSamples(flat, _canvas);

      for (final p in g.points) {
        expect(p.dy.isFinite, isTrue, reason: 'NaN would erase the chart');
        expect(p.dy, closeTo(_canvas.height / 2, 0.001));
      }
    });

    test('samples all at one distance do not divide by zero either', () {
      // A runner standing still with a drifting barometer.
      const stationary = [
        ElevationSample(distanceM: 0, altitudeM: 100),
        ElevationSample(distanceM: 0, altitudeM: 104),
      ];

      final g = ElevationChartGeometry.fromSamples(stationary, _canvas);

      for (final p in g.points) {
        expect(p.dx.isFinite, isTrue);
        expect(p.dy.isFinite, isTrue);
      }
    });

    test('fewer than two samples is not drawable', () {
      expect(
        ElevationChartGeometry.fromSamples(const [], _canvas).isDrawable,
        isFalse,
      );
      expect(
        ElevationChartGeometry.fromSamples(const [
          ElevationSample(distanceM: 0, altitudeM: 100),
        ], _canvas).isDrawable,
        isFalse,
      );
    });
  });

  group('widget', () {
    Future<void> pump(WidgetTester tester, List<ElevationSample> samples) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ElevationChart(samples: samples)),
          ),
        );

    testWidgets('a run with relief renders the chart', (tester) async {
      await pump(tester, _ramp());

      expect(find.byType(CustomPaint), findsWidgets);
      // The extremes are labelled so the shape has a scale to be read against.
      expect(find.text('200 m'), findsOneWidget);
      expect(find.text('100 m'), findsOneWidget);
    });

    testWidgets('too little data renders nothing at all', (tester) async {
      // A phone with no barometer and no GPS height must hide the feature, never occupy the
      // screen with an empty box.
      await pump(tester, const []);

      expect(find.byType(ElevationChart), findsOneWidget);
      // Scoped to the chart's own subtree: Scaffold builds CustomPaints of its own, so a bare
      // byType here would be asserting against the framework rather than this widget.
      expect(
        find.descendant(
          of: find.byType(ElevationChart),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(tester.getSize(find.byType(ElevationChart)), Size.zero);
    });
  });
}
