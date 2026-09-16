import 'package:claimtrek/device/device_sensors.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/geo/projection.dart';
import 'package:claimtrek/geo/territory_engine.dart';
import 'package:claimtrek/ui/summary/run_summary_screen.dart';
import 'package:claimtrek/ui/tracking/tracking_controller.dart';
import 'package:clipper2/clipper2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const origin = LatLng(50.7217, 10.4483);

LatLng at(double eastM, double northM) =>
    Projection.unproject(PointD(eastM, northM), origin);

/// A 100 m square, densified so it reads as a track rather than four corners.
List<LatLng> squareTrack() {
  const corners = [
    [0.0, 0.0],
    [100.0, 0.0],
    [100.0, 100.0],
    [0.0, 100.0],
  ];
  final out = <LatLng>[];
  for (var i = 0; i < corners.length; i++) {
    final a = corners[i];
    final b = corners[(i + 1) % corners.length];
    for (var s = 0; s < 8; s++) {
      final t = s / 8;
      out.add(at(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t));
    }
  }
  return out;
}

/// A run that never closed its loop: a real track, but no geometry and no area.
PendingRun unclosedRun() {
  final track = squareTrack().take(20).toList();
  return PendingRun(
    claim: null,
    reference: origin,
    track: track,
    areaM2: 0,
    stolenAreaM2: 0,
    stolenFromCount: 0,
    distanceM: 340,
    duration: const Duration(minutes: 2, seconds: 5),
    steps: 410,
    elevationGainM: 3,
    verified: false,
    plausibleRatio: 0.2,
    startedAt: DateTime(2026, 9, 8, 7),
  );
}

PendingRun pendingRun({
  bool verified = true,
  double stolenAreaM2 = 5987,
  int stolenFromCount = 3,
  int steps = 812,
  double elevationGainM = 14,
}) {
  final track = squareTrack();
  return PendingRun(
    claim: TerritoryEngine.buildTerritoryGeographic(track, origin)!,
    reference: origin,
    track: track,
    areaM2: 32400,
    stolenAreaM2: stolenAreaM2,
    stolenFromCount: stolenFromCount,
    distanceM: 688,
    duration: const Duration(minutes: 4, seconds: 12),
    steps: steps,
    elevationGainM: elevationGainM,
    verified: verified,
    plausibleRatio: verified ? 1.0 : 0.3,
    startedAt: DateTime(2026, 9, 8, 7),
  );
}

/// Stands in for the real controller so the screen can render with no database, no GPS and no
/// bootstrap. [build] is overridden entirely, so nothing async is started.
class FakeTrackingController extends TrackingController {
  FakeTrackingController(this._availability);

  final SensorAvailability _availability;
  bool discarded = false;
  String? savedTitle;

  @override
  TrackingState build() =>
      const TrackingState.initial().copyWith(availability: _availability);

  @override
  Future<void> saveRun({String? title}) async {
    savedTitle = title;
  }

  @override
  void discardRun() {
    discarded = true;
  }
}

void main() {
  group('formatDuration', () {
    test('reads as minutes and seconds', () {
      expect(formatDuration(const Duration(minutes: 4, seconds: 12)), '4:12');
    });

    test('pads the seconds so 4:05 never reads as 4:5', () {
      expect(formatDuration(const Duration(minutes: 4, seconds: 5)), '4:05');
    });

    test('grows an hours field only when there are hours', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });
  });

  group('formatArea', () {
    test('reads as hectares once the numbers get big', () {
      expect(formatArea(32400), '3.24 ha');
    });

    test('stays in square metres below a hectare', () {
      expect(formatArea(5987), '5987 m²');
    });
  });

  group('screen', () {
    late FakeTrackingController fake;

    Future<void> pump(
      WidgetTester tester, {
      required PendingRun run,
      SensorAvailability availability = const SensorAvailability.none(),
    }) async {
      fake = FakeTrackingController(availability);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [trackingControllerProvider.overrideWith(() => fake)],
          child: MaterialApp(home: RunSummaryScreen(run: run)),
        ),
      );
      await tester.pump();
    }

    testWidgets('leads with what the run took', (tester) async {
      await pump(tester, run: pendingRun());

      expect(find.text('3.24 ha'), findsOneWidget);
      expect(find.text('5987 m²'), findsOneWidget);
      expect(find.text('from 3 players'), findsOneWidget);
    });

    testWidgets('a run that stole nothing says so rather than showing 0', (
      tester,
    ) async {
      await pump(
        tester,
        run: pendingRun(stolenAreaM2: 0, stolenFromCount: 0),
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('from 0'), findsNothing);
    });

    testWidgets('distance and time always show', (tester) async {
      await pump(tester, run: pendingRun());

      expect(find.text('688 m'), findsOneWidget);
      expect(find.text('4:12'), findsOneWidget);
    });

    testWidgets('steps and climb are hidden when the device lacks the sensors', (
      tester,
    ) async {
      // Same rule as the map: a missing sensor hides its feature rather than showing a zero
      // that looks like the runner stood still.
      await pump(tester, run: pendingRun());

      expect(find.text('STEPS'), findsNothing);
      expect(find.text('CLIMB'), findsNothing);
    });

    testWidgets('steps and climb show when the sensors exist', (tester) async {
      await pump(
        tester,
        run: pendingRun(),
        availability: const SensorAvailability(
          accelerometer: true,
          barometer: true,
          pedometer: true,
          compass: true,
        ),
      );

      expect(find.text('812'), findsOneWidget);
      expect(find.text('14 m'), findsOneWidget);
    });

    testWidgets('an unverified run is told it will not score', (tester) async {
      // This is the moment it matters — the runner is deciding whether to keep the run.
      await pump(tester, run: pendingRun(verified: false));

      expect(find.textContaining('not count on the leaderboard'), findsOneWidget);
    });

    testWidgets('a verified run carries no warning', (tester) async {
      await pump(tester, run: pendingRun());

      expect(find.textContaining('not count on the leaderboard'), findsNothing);
    });

    testWidgets('the name is pre-filled so Save is one tap', (tester) async {
      await pump(tester, run: pendingRun());

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isNotEmpty);
    });

    testWidgets('an unclosed run says nothing was claimed', (tester) async {
      await pump(tester, run: unclosedRun());

      expect(find.text('No loop closed — nothing claimed.'), findsOneWidget);
      expect(find.text('CLAIMED'), findsNothing);
      expect(find.text('STOLEN'), findsNothing);
    });

    testWidgets('an unclosed run still shows the effort', (tester) async {
      // The path and the numbers are the whole point of keeping it.
      await pump(tester, run: unclosedRun());

      expect(find.text('340 m'), findsOneWidget);
      expect(find.text('2:05'), findsOneWidget);
    });

    testWidgets('an unclosed run is not warned about the leaderboard', (
      tester,
    ) async {
      // It took no ground, so there is nothing to exclude and the warning would be noise.
      await pump(tester, run: unclosedRun());

      expect(find.textContaining('not count on the leaderboard'), findsNothing);
    });

    testWidgets('an unclosed run can still be saved', (tester) async {
      await pump(tester, run: unclosedRun());

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fake.savedTitle, isNotNull);
    });

    testWidgets('Discard tells the controller and leaves', (tester) async {
      await pump(tester, run: pendingRun());

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(fake.discarded, isTrue);
    });

    testWidgets('Save passes the typed name through', (tester) async {
      await pump(tester, run: pendingRun());

      await tester.enterText(find.byType(TextField), 'Hill loop');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fake.savedTitle, 'Hill loop');
    });
  });
}
