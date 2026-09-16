import 'dart:math' as math;

/// Anti-cheat. Pure Dart, no plugin imports, so it can be driven from a unit test with a
/// synthetic waveform instead of a treadmill.
///
/// A phone in a moving car sees a smooth GPS track and almost no vertical bounce. A phone on a
/// running human sees a strong 1.5-3 Hz oscillation — that is the gait. We estimate the
/// dominant frequency of accelerometer magnitude and cross-check it against GPS speed.
///
/// Estimation is by upward zero-crossings of the mean-removed signal rather than an FFT: one
/// pass, no allocation per sample, and entirely good enough to tell a stride from a wheel.
class CadenceAnalyzer {
  CadenceAnalyzer({this.windowSeconds = 4.0});

  final double windowSeconds;

  static const double _minStdDev = 0.35;

  /// Sized for the highest rate a game-speed sensor realistically delivers.
  static const int _capacity = 1024;

  final List<int> _times = List<int>.filled(_capacity, 0);
  final List<double> _values = List<double>.filled(_capacity, 0);
  int _head = 0;
  int _count = 0;

  double _cadenceHz = 0;

  double get cadenceHz => _cadenceHz;

  /// Feed one raw accelerometer triple. [timestampNanos] is the sensor event timestamp.
  void onAcceleration(double x, double y, double z, int timestampNanos) {
    _push(timestampNanos, math.sqrt(x * x + y * y + z * z));
    _cadenceHz = _estimate();
  }

  void _push(int t, double v) {
    _times[_head] = t;
    _values[_head] = v;
    _head = (_head + 1) % _capacity;
    if (_count < _capacity) _count++;
    _dropOlderThanWindow(t);
  }

  void _dropOlderThanWindow(int now) {
    final cutoff = now - (windowSeconds * 1000000000).toInt();
    while (_count > 0 && _timeAt(0) < cutoff) {
      _count--;
    }
  }

  int _index(int i) => (_head - _count + i) % _capacity + _capacity;

  int _timeAt(int i) => _times[_index(i) % _capacity];

  double _valueAt(int i) => _values[_index(i) % _capacity];

  /// Mean-removed upward crossings over the window. Two crossings would be one full cycle, so
  /// upward crossings alone already count cycles.
  double _estimate() {
    if (_count < 16) return 0;

    var sum = 0.0;
    for (var i = 0; i < _count; i++) {
      sum += _valueAt(i);
    }
    final mean = sum / _count;

    // Reject a window with no meaningful movement: pure noise crosses the mean constantly.
    var variance = 0.0;
    for (var i = 0; i < _count; i++) {
      final d = _valueAt(i) - mean;
      variance += d * d;
    }
    final stdDev = math.sqrt(variance / _count);
    if (stdDev < _minStdDev) return 0;

    // A crossing only counts once the signal has swung clear of the noise floor, which is what
    // keeps a jittery pocket from reading as a sprint.
    final hysteresis = stdDev * 0.5;
    var crossings = 0;
    var armed = false;
    for (var i = 0; i < _count; i++) {
      final d = _valueAt(i) - mean;
      if (!armed && d < -hysteresis) armed = true;
      if (armed && d > hysteresis) {
        crossings++;
        armed = false;
      }
    }

    final spanNanos = _timeAt(_count - 1) - _timeAt(0);
    if (spanNanos <= 0) return 0;
    final spanSeconds = spanNanos / 1000000000.0;
    if (spanSeconds < windowSeconds * 0.4) return 0;

    return crossings / spanSeconds;
  }

  void reset() {
    _count = 0;
    _head = 0;
    _cadenceHz = 0;
  }

  /// The judgement itself, kept as a pure function so the thresholds are testable and
  /// reviewable in one place.
  static bool isPlausible({
    required double speedMs,
    required double cadenceHz,
  }) {
    if (speedMs < 0.5) return true; // standing still is always fine
    if (cadenceHz < 0.8) return false; // moving with no gait at all = vehicle
    if (speedMs > 8.0) return false; // 28 km/h is not a run
    return true;
  }
}

/// Rolling share of samples that looked like a human.
///
/// Below [verifiedThreshold] the run is still saved — it is just marked unverified, drawn
/// hatched, and left out of the leaderboard. Rejecting outright would punish anyone whose
/// phone sat still in a backpack.
class PlausibilityTracker {
  static const double verifiedThreshold = 0.8;
  static const int _minSamples = 10;

  int _total = 0;
  int _plausible = 0;

  void record(bool ok) {
    _total++;
    if (ok) _plausible++;
  }

  double get ratio => _total == 0 ? 1.0 : _plausible / _total;

  bool get verified => _total < _minSamples || ratio >= verifiedThreshold;

  void reset() {
    _total = 0;
    _plausible = 0;
  }
}
