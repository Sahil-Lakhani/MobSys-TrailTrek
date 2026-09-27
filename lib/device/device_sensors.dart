import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'sensor_probe.dart';

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

  const SensorAvailability.none()
    : accelerometer = false,
      barometer = false,
      pedometer = false,
      compass = false;

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<SensorAvailability> probe({
    Duration timeout = SensorProbe.defaultTimeout,
  }) async {
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

class BarometerSource {
  Stream<double> start() => barometerEventStream().map((e) => e.pressure);
}

class PedometerSource {
  Stream<int> start() => Pedometer.stepCountStream.map((e) => e.steps);
}

class CompassSource {
  Stream<double> start() =>
      (FlutterCompass.events ?? const Stream<CompassEvent>.empty())
          .map((e) => e.heading)
          .where((h) => h != null)
          .cast<double>();
}

class Haptics {
  const Haptics();

  Future<void> loopClosed() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
    }
  }
}
