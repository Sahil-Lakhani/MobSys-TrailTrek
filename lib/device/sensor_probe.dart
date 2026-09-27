import 'dart:async';

class SensorProbe {
  SensorProbe._();

  static const Duration defaultTimeout = Duration(milliseconds: 1200);

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
      return false;
    }

    timer = Timer(timeout, () => settle(false));
    return completer.future;
  }
}
