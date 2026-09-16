import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'sensor_probe.dart';

/// Plugin-backed sensor adapters.
///
/// These live here rather than in `lib/sensor/` because that directory is purity-guarded — a
/// test fails the build if anything under it imports Flutter. `CadenceAnalyzer` and `Barometer`
/// stay pure maths that a unit test can drive with a synthetic waveform; this file is the thin
/// layer that feeds them real samples.
///
/// Every source here is probed before use and reports its own availability. Nothing in the UI
/// may assume a sensor exists.

/// What the device actually has. Resolved once at startup.
class SensorAvailability {
  final bool accelerometer;
  final bool barometer;
  final bool pedometer;
  final bool compass;

  const SensorAvailability({
    required this.accelerometer,
    required this.barometer,
    required this.pedometer,
    required this.compass,
  });

  /// The conservative default used until the probe resolves, and in tests. Nothing is claimed
  /// to exist, so no feature renders on an assumption.
  const SensorAvailability.none()
    : accelerometer = false,
      barometer = false,
      pedometer = false,
      compass = false;

  /// Whether this platform can have these sensors at all.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Probes every sensor at once. One slow absent sensor then costs the probe timeout in total
  /// rather than that timeout multiplied by four.
  static Future<SensorAvailability> probe({
    Duration timeout = SensorProbe.defaultTimeout,
  }) async {
    // Off mobile there is nothing to find, and worse, merely *calling* the stream getters
    // fires a method-channel request that fails as an unhandled async error rather than one
    // this code can catch. Not asking is the only way to not be told.
    if (!isSupportedPlatform) return const SensorAvailability.none();

    final results = await Future.wait([
      SensorProbe.isAvailable(accelerometerEventStream(), timeout: timeout),
      SensorProbe.isAvailable(barometerEventStream(), timeout: timeout),
      SensorProbe.isAvailable(Pedometer.stepCountStream, timeout: timeout),
      SensorProbe.isAvailable(
        FlutterCompass.events ?? const Stream<CompassEvent>.empty(),
        timeout: timeout,
      ),
    ]);

    return SensorAvailability(
      accelerometer: results[0],
      barometer: results[1],
      pedometer: results[2],
      compass: results[3],
    );
  }
}

/// Raw accelerometer samples, shaped for [CadenceAnalyzer.onAcceleration].
///
/// `sensors_plus` reports a wall-clock `DateTime` rather than the sensor event timestamp the
/// analyser wants in nanoseconds, so it is converted here. The analyser only ever takes
/// differences between timestamps, so the epoch it counts from does not matter — only that the
/// scale is nanoseconds and the sequence is monotonic.
class AccelerometerSource {
  Stream<({double x, double y, double z, int timestampNanos})> start() =>
      accelerometerEventStream().map(
        (e) => (
          x: e.x,
          y: e.y,
          z: e.z,
          timestampNanos: e.timestamp.microsecondsSinceEpoch * 1000,
        ),
      );
}

/// Barometric pressure in hectopascals, for [Barometer].
class BarometerSource {
  Stream<double> start() => barometerEventStream().map((e) => e.pressure);
}

/// Cumulative step count since boot.
///
/// The platform counter does not reset per run, so the run's own step total is the difference
/// from the first reading seen after the run started. That subtraction is the caller's job.
class PedometerSource {
  Stream<int> start() => Pedometer.stepCountStream.map((e) => e.steps);
}

/// Heading in degrees from magnetic north, or null when the reading is untrustworthy.
class CompassSource {
  Stream<double> start() =>
      (FlutterCompass.events ?? const Stream<CompassEvent>.empty())
          .map((e) => e.heading)
          .where((h) => h != null)
          .cast<double>();
}

/// One pulse when a loop closes.
///
/// Flutter ships this, so no `vibration` dependency is added for a single buzz. Failures are
/// swallowed: a device with no vibrator must not take down the claim that just succeeded.
class Haptics {
  const Haptics();

  Future<void> loopClosed() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // No vibrator, or the platform refused. Not worth a single frame of the run.
    }
  }
}
