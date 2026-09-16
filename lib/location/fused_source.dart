import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../geo/lat_lng.dart';
import 'location_source.dart';

/// Real GPS.
///
/// Deliberately thin: it converts a `Position` into a [Fix] and nothing else. Every judgement
/// about whether a fix is usable lives in [LocationSource.accept], outside this class, which is
/// what lets that judgement be unit-tested without a device. This adapter cannot be.
class FusedSource implements LocationSource {
  FusedSource({this.trackingNotification = true});

  /// Off for a background position lookup — seeding the map does not warrant a notification.
  /// On for a recording run, where losing fixes to Android's throttling is what turns a loop
  /// into a triangle.
  final bool trackingNotification;

  /// 3 m. Tight enough that a loop's corners land where they were run, loose enough that
  /// standing still does not fill the track with jitter.
  static const int distanceFilterM = 3;

  /// How often the provider may deliver, when the distance filter is satisfied.
  ///
  /// `geolocator` defaults this to 5 s, which is far too coarse here: at a running pace of
  /// 3 m/s that is a fix every 15 m, so a loop comes back with its corners rounded off and its
  /// area wrong. The provider also drops updates that arrive inside the interval outright —
  /// visible in logcat as `FusedLocation: location delivery blocked - too fast` — so the
  /// interval, not the distance filter, silently becomes the real sample rate.
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
          // Surfaced rather than swallowed: losing the fix stream mid-run must reach the UI,
          // not leave a stalled track that looks like standing still.
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
            // Holds the CPU awake so fixes keep arriving with the screen off. Without it
            // Android throttles updates and the polygon loses its corners.
            enableWakeLock: true,
            setOngoing: true,
          )
        : null,
  );

  /// `Position` carries fields a [Fix] has no use for; this is the whole conversion.
  ///
  /// Speed is clamped at zero because some receivers report a small negative value when
  /// stationary, and a negative speed would sail through the plausibility check unnoticed.
  static Fix toFix(Position position) => Fix(
    point: LatLng(position.latitude, position.longitude),
    accuracyM: position.accuracy,
    speedMs: position.speed < 0 ? 0 : position.speed,
    altitudeM: position.altitude,
    timestampMs: position.timestamp.millisecondsSinceEpoch,
  );

  /// One position now, for centring the map and seeding rivals before any run starts.
  ///
  /// Returns null rather than throwing: no fix yet is an ordinary state indoors, and the map
  /// has a designed screen for it.
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
