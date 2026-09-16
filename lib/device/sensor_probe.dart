import 'dart:async';

/// Is this sensor actually here?
///
/// A Dart stream for an absent sensor does not error. It simply never emits, which is
/// indistinguishable from a sensor that is present but idle. Every plugin-backed source in this
/// directory therefore subscribes, waits a short time for the first event, and treats silence
/// as absence.
///
/// The rule this exists to serve: **a missing sensor hides its feature, it never fails the
/// runner.** Never a greyed-out control, never a "not supported" message.
class SensorProbe {
  SensorProbe._();

  /// Long enough for a game-rate sensor to deliver something, short enough that a device
  /// without the hardware does not stall the first frame behind it.
  static const Duration defaultTimeout = Duration(milliseconds: 1200);

  /// Resolves true if [stream] produces one event within [timeout].
  ///
  /// An error on the stream counts as absent: some platforms report a missing sensor by
  /// throwing on subscribe rather than by staying silent, and both mean the same thing here.
  static Future<bool> isAvailable<T>(
    Stream<T> stream, {
    Duration timeout = defaultTimeout,
  }) async {
    final completer = Completer<bool>();
    StreamSubscription<T>? subscription;
    Timer? timer;

    void settle(bool available) {
      if (completer.isCompleted) return;
      timer?.cancel();
      unawaited(subscription?.cancel());
      completer.complete(available);
    }

    try {
      subscription = stream.listen(
        (_) => settle(true),
        onError: (Object _) => settle(false),
        cancelOnError: true,
      );
    } catch (_) {
      // Subscribing itself can throw on a platform with no such sensor.
      return false;
    }

    timer = Timer(timeout, () => settle(false));
    return completer.future;
  }
}
