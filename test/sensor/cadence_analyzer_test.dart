import 'dart:math' as math;

import 'package:claimtrek/sensor/barometer.dart';
import 'package:claimtrek/sensor/cadence_analyzer.dart';
import 'package:test/test.dart';

/// Feed a synthetic gait signal: gravity plus a bounce at [hz].
void feed(
  CadenceAnalyzer analyzer,
  double hz,
  double seconds, {
  double amplitude = 3.0,
}) {
  const rateHz = 50.0;
  final samples = (seconds * rateHz).toInt();
  for (var i = 0; i < samples; i++) {
    final t = i / rateHz;
    final z = 9.81 + amplitude * math.sin(2 * math.pi * hz * t);
    analyzer.onAcceleration(0, 0, z, (t * 1000000000).toInt());
  }
}

void main() {
  test('a two hertz bounce reads as roughly two hertz', () {
    final analyzer = CadenceAnalyzer();
    feed(analyzer, 2.0, 8.0);
    expect(analyzer.cadenceHz, closeTo(2.0, 0.35));
  });

  test('a three hertz bounce reads as roughly three hertz', () {
    final analyzer = CadenceAnalyzer();
    feed(analyzer, 3.0, 8.0);
    expect(analyzer.cadenceHz, closeTo(3.0, 0.4));
  });

  test('a phone riding in a car reports no cadence', () {
    final analyzer = CadenceAnalyzer();
    // Near-constant acceleration with only tiny road noise: no gait to find.
    feed(analyzer, 0.4, 8.0, amplitude: 0.05);
    expect(
      analyzer.cadenceHz,
      lessThan(0.8),
      reason: 'engine vibration is not a stride',
    );
  });

  test('reset clears the window', () {
    final analyzer = CadenceAnalyzer();
    feed(analyzer, 2.0, 8.0);
    expect(analyzer.cadenceHz, greaterThan(0));
    analyzer.reset();
    expect(analyzer.cadenceHz, 0);
  });

  test('standing still is always plausible', () {
    expect(
      CadenceAnalyzer.isPlausible(speedMs: 0.1, cadenceHz: 0),
      isTrue,
    );
  });

  test('moving fast with no gait is rejected', () {
    expect(
      CadenceAnalyzer.isPlausible(speedMs: 6, cadenceHz: 0.2),
      isFalse,
    );
  });

  test('running is accepted and a sprint beyond human speed is not', () {
    expect(
      CadenceAnalyzer.isPlausible(speedMs: 3.2, cadenceHz: 2.6),
      isTrue,
    );
    expect(
      CadenceAnalyzer.isPlausible(speedMs: 12, cadenceHz: 2.6),
      isFalse,
    );
  });

  test('a run stays verified until implausible samples pass one in five', () {
    final tracker = PlausibilityTracker();
    for (var i = 0; i < 85; i++) {
      tracker.record(true);
    }
    for (var i = 0; i < 15; i++) {
      tracker.record(false);
    }
    expect(tracker.verified, isTrue);

    for (var i = 0; i < 20; i++) {
      tracker.record(false);
    }
    expect(tracker.verified, isFalse);
  });

  test('a fresh tracker is verified rather than guilty until proven', () {
    expect(PlausibilityTracker().verified, isTrue);
    expect(PlausibilityTracker().ratio, closeTo(1.0, 0.0001));
  });

  test('barometric altitude falls as pressure rises', () {
    final high = Barometer.altitudeMetres(900);
    final low = Barometer.altitudeMetres(1013.25);
    expect(low, closeTo(0.0, 0.5));
    expect(high, greaterThan(900));
  });

  test('elevation gain ignores drift below the noise floor', () {
    expect(Barometer.accumulateGain(100, 100.3), closeTo(0, 0.001));
    expect(Barometer.accumulateGain(100, 102), closeTo(2, 0.001));
    expect(Barometer.accumulateGain(100, 95), closeTo(0, 0.001));
  });

  test('smoothing latches onto the first real sample', () {
    // Starting from zero must not drag the first reading toward the origin, or the elevation
    // trace opens with a phantom climb from sea level.
    expect(Barometer.smooth(0, 340), closeTo(340, 0.001));
    expect(Barometer.smooth(340, 350), closeTo(341.5, 0.001));
  });
}
