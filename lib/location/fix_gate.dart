import '../geo/projection.dart';
import 'location_source.dart';

class FixVerdict {
  const FixVerdict({
    required this.accepted,
    required this.creditsDistance,
    required this.brokeTrack,
  });

  const FixVerdict.rejected()
    : accepted = false,
      creditsDistance = false,
      brokeTrack = false;

  final bool accepted;

  final bool creditsDistance;

  final bool brokeTrack;
}

class FixGate {
  static const double maxImpliedSpeedMs = 12.0;

  static const Duration maxGap = Duration(seconds: 20);

  static const int rejectionsBeforeResync = 3;

  Fix? _last;
  int _consecutiveRejections = 0;

  void reset() {
    _last = null;
    _consecutiveRejections = 0;
  }

  FixVerdict admit(Fix fix) {
    final previous = _last;

    if (previous == null) {
      _last = fix;
      _consecutiveRejections = 0;
      return const FixVerdict(
        accepted: true,
        creditsDistance: false,
        brokeTrack: false,
      );
    }

    final elapsedMs = fix.timestampMs - previous.timestampMs;

    if (elapsedMs < 0) return const FixVerdict.rejected();

    final metres = Projection.haversine(previous.point, fix.point);

    if (elapsedMs == 0) {
      _last = fix;
      _consecutiveRejections = 0;
      return const FixVerdict(
        accepted: true,
        creditsDistance: false,
        brokeTrack: false,
      );
    }

    if (elapsedMs > maxGap.inMilliseconds) {
      _last = fix;
      _consecutiveRejections = 0;
      return const FixVerdict(
        accepted: true,
        creditsDistance: false,
        brokeTrack: true,
      );
    }

    final impliedSpeedMs = metres / (elapsedMs / 1000.0);
    if (impliedSpeedMs > maxImpliedSpeedMs) {
      _consecutiveRejections++;

      if (_consecutiveRejections >= rejectionsBeforeResync) {
        _last = fix;
        _consecutiveRejections = 0;
        return const FixVerdict(
          accepted: true,
          creditsDistance: false,
          brokeTrack: true,
        );
      }

      return const FixVerdict.rejected();
    }

    _last = fix;
    _consecutiveRejections = 0;
    return const FixVerdict(
      accepted: true,
      creditsDistance: true,
      brokeTrack: false,
    );
  }
}
