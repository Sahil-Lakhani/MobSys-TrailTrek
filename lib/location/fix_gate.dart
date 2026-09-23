import '../geo/projection.dart';
import 'location_source.dart';

/// What the gate decided about one fix.
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

  /// Whether the point belongs on the track at all.
  final bool accepted;

  /// Whether the leg from the previous point is ground the runner actually covered. False
  /// across a signal gap or a resync, where the straight line is an artefact rather than a route.
  final bool creditsDistance;

  /// Whether continuity with the previous point was lost.
  final bool brokeTrack;
}

/// The stateful half of fix filtering: is this fix plausible *given the last one*.
///
/// [LocationSource.accept] judges a fix on its own — accuracy and reported speed — and that is
/// genuinely all it can do without history. It cannot catch the failure that actually distorts
/// a claim: a fix 80 m from the truth that reports 6 m accuracy and a walking pace, which is
/// what multipath between buildings produces. Only the distance from the previous fix, against
/// the time between them, reveals it.
///
/// Pure and stateful, so every rule here is unit-testable without a device.
class FixGate {
  /// Above this, the leg was not run. A fast sprint is about 10 m/s; the headroom keeps an
  /// honest burst after a pause from being thrown away.
  static const double maxImpliedSpeedMs = 12.0;

  /// Longer than this between fixes and the straight line between them is not a route — it is
  /// wherever the runner went while the receiver could not see them.
  static const Duration maxGap = Duration(seconds: 20);

  /// After this many refusals in a row the anchor is assumed to be the stale one. A runner who
  /// genuinely relocated must not be locked out of their own track by a gate that keeps
  /// measuring from a position they left.
  static const int rejectionsBeforeResync = 3;

  Fix? _last;
  int _consecutiveRejections = 0;

  /// Forgets everything. Called between runs, so one run's last position cannot reject the
  /// first fix of the next.
  void reset() {
    _last = null;
    _consecutiveRejections = 0;
  }

  FixVerdict admit(Fix fix) {
    final previous = _last;

    // Nothing to compare against: take it, but there is no leg to measure yet.
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

    // Out of order. Some receivers replay a buffered fix after a newer one, and a negative
    // interval makes the implied speed negative — which passes every upper bound there is.
    if (elapsedMs < 0) return const FixVerdict.rejected();

    final metres = Projection.haversine(previous.point, fix.point);

    // Same instant: no interval to divide by, so plausibility cannot be judged. Keep the point
    // and decline to credit a leg whose duration is unknown.
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
        // The runner was somewhere during those seconds; the straight line back is not it.
        creditsDistance: false,
        brokeTrack: true,
      );
    }

    final impliedSpeedMs = metres / (elapsedMs / 1000.0);
    if (impliedSpeedMs > maxImpliedSpeedMs) {
      _consecutiveRejections++;

      // Repeatedly implausible against the same anchor means the anchor is the problem.
      if (_consecutiveRejections >= rejectionsBeforeResync) {
        _last = fix;
        _consecutiveRejections = 0;
        return const FixVerdict(
          accepted: true,
          creditsDistance: false,
          brokeTrack: true,
        );
      }

      // The outlier is not adopted as the new reference, or one bad fix drags the anchor with
      // it and the next honest fix looks like the jump.
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
