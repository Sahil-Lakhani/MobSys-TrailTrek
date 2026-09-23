/// One point on a run's elevation profile: how far in, and how high.
///
/// Distance rather than timestamp on the x-axis, because a profile is a picture of the ground
/// covered — a runner stopped at a crossing should not stretch the hill they are standing on.
class ElevationSample {
  const ElevationSample({required this.distanceM, required this.altitudeM});

  /// Cumulative distance from the start of the run, in metres.
  final double distanceM;

  /// Altitude in metres. Barometric where the sensor exists, GPS height otherwise.
  final double altitudeM;
}

/// Profile <-> string, so a run's elevation lives in one text column beside its path.
///
/// Stores explicit `distance,altitude` pairs rather than an altitude array aligned to
/// [PathCodec]'s vertices. The pairs cost a few more bytes and buy independence: a truncated
/// path cannot silently shift the profile sideways, and the chart can be read without the
/// track.
class ElevationCodec {
  ElevationCodec._();

  /// One decimal is 10 cm, well past what a barometer resolves through its own drift.
  static const int _decimals = 1;

  static String encode(List<ElevationSample> samples) => samples
      .map(
        (s) =>
            '${s.distanceM.toStringAsFixed(_decimals)},'
            '${s.altitudeM.toStringAsFixed(_decimals)}',
      )
      .join(';');

  /// Skips malformed pairs rather than throwing or returning null — the same bargain
  /// [PathCodec] strikes. One mangled sample should cost a point of the chart, not the run.
  static List<ElevationSample> decode(String encoded) {
    if (encoded.trim().isEmpty) return const [];

    final out = <ElevationSample>[];
    for (final pair in encoded.split(';')) {
      final parts = pair.split(',');
      if (parts.length != 2) continue;
      final distance = double.tryParse(parts[0]);
      final altitude = double.tryParse(parts[1]);
      if (distance == null || altitude == null) continue;
      out.add(ElevationSample(distanceM: distance, altitudeM: altitude));
    }
    return out;
  }
}
