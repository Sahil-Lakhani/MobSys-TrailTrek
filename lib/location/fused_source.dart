import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../geo/lat_lng.dart';
import 'location_source.dart';

class FusedSource implements LocationSource {
  FusedSource({this.trackingNotification = true});

  final bool trackingNotification;

  static const int distanceFilterM = 3;

  static const Duration updateInterval = Duration(seconds: 1);

  StreamSubscription<Position>? _subscription;
  StreamController<Fix>? _controller;

  @override
  Stream<Fix> start() {
    final controller = StreamController<Fix>(onCancel: stop);
    _controller = controller;

    _subscription =
        Geolocator.getPositionStream(
          locationSettings: _settings(),
        ).listen(
          (position) => controller.add(toFix(position)),
          onError: controller.addError,
        );

    return controller.stream;
  }

  LocationSettings _settings() => AndroidSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: distanceFilterM,
    intervalDuration: updateInterval,
    foregroundNotificationConfig: trackingNotification
        ? const ForegroundNotificationConfig(
            notificationTitle: 'ClaimTrek',
            notificationText: 'Recording your run',
            notificationChannelName: 'Run tracking',
            enableWakeLock: true,
            setOngoing: true,
          )
        : null,
  );

  static Fix toFix(Position position) => Fix(
    point: LatLng(position.latitude, position.longitude),
    accuracyM: position.accuracy,
    speedMs: position.speed < 0 ? 0 : position.speed,
    altitudeM: position.altitude,
    timestampMs: position.timestamp.millisecondsSinceEpoch,
  );

  static Future<Fix?> currentFix() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return toFix(position);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) await controller.close();
  }
}
