import 'package:claimtrek/device/device_sensors.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/location/location_source.dart';
import 'package:claimtrek/ui/tracking/run_stats_hud.dart';
import 'package:claimtrek/ui/tracking/tracking_controller.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatting', () {
    test('elapsed time reads like a stopwatch', () {
      expect(formatElapsed(const Duration(seconds: 5)), '0:05');
      expect(formatElapsed(const Duration(minutes: 12, seconds: 7)), '12:07');
      expect(
        formatElapsed(const Duration(hours: 1, minutes: 3, seconds: 9)),
        '1:03:09',
      );
    });

    test('distance switches to kilometres once it earns them', () {
      expect(formatDistance(0), '0 m');
      expect(formatDistance(842), '842 m');
      expect(formatDistance(1000), '1.00 km');
      expect(formatDistance(2345), '2.35 km');
    });

    test('pace is minutes per kilometre, or a dash when standing still', () {
      // 3 m/s is a 5:33 /km pace.
      expect(formatPace(3.0), '5:33 /km');
      expect(formatPace(0), '—');
      // Slower than a walk is noise, not a pace worth reporting.
      expect(formatPace(0.2), '—');
    });
  });

  group('RunStatsHud', () {
    TrackingState running({
      SensorAvailability availability = const SensorAvailability.none(),
      double? altitudeM,
      Fix? fix,
    }) => const TrackingState.initial().copyWith(
      running: true,
      status: 'Tracking…',
      startedAt: clock.now().subtract(const Duration(minutes: 2)),
      distanceM: 1500,
      closureProgress: 0.4,
      steps: 1234,
      elevationGainM: 12,
      altitudeM: altitudeM,
      currentFix: fix,
      availability: availability,
    );

    Future<void> pump(WidgetTester tester, TrackingState state) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RunStatsHud(state: state))),
      );
      // Pump once so the initial tick lands; never `pumpAndSettle`, the timer never settles.
      await tester.pump();
    }

    testWidgets('shows the always-available counters', (tester) async {
      await pump(tester, running());

      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('1.50 km'), findsOneWidget);
      expect(find.text('CLOSURE'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('PACE'), findsOneWidget);

      // Nothing behind these on this host, so the rows must not appear.
      expect(find.text('STEPS'), findsNothing);
      expect(find.text('CLIMB'), findsNothing);
      expect(find.text('ALTITUDE'), findsNothing);
      expect(find.text('GPS'), findsNothing);
    });

    testWidgets('elapsed time keeps ticking without new fixes', (tester) async {
      await pump(tester, running());
      expect(find.text('2:00'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('2:03'), findsOneWidget);
    });

    testWidgets('sensor rows appear only with the sensor behind them', (
      tester,
    ) async {
      await pump(
        tester,
        running(
          availability: const SensorAvailability(
            accelerometer: true,
            barometer: true,
            pedometer: true,
            compass: false,
          ),
          altitudeM: 321.4,
          fix: Fix(
            point: const LatLng(50.72, 10.45),
            accuracyM: 7.6,
            speedMs: 3.0,
            timestampMs: 0,
          ),
        ),
      );

      expect(find.text('STEPS'), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
      expect(find.text('CLIMB'), findsOneWidget);
      expect(find.text('12 m'), findsOneWidget);
      expect(find.text('ALTITUDE'), findsOneWidget);
      expect(find.text('321 m'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);
      expect(find.text('±8 m'), findsOneWidget);
      expect(find.text('5:33 /km'), findsOneWidget);
    });

    testWidgets('altitude from GPS alone still shows', (tester) async {
      // No barometer, but the receiver reports a height — that is still an altitude.
      await pump(tester, running(altitudeM: 100));
      expect(find.text('ALTITUDE'), findsOneWidget);
      expect(find.text('100 m'), findsOneWidget);
    });
  });
}
