class ElevationSample {
  const ElevationSample({required this.distanceM, required this.altitudeM});

  final double distanceM;

  final double altitudeM;
}

class ElevationCodec {
  ElevationCodec._();

  static const int _decimals = 1;

  static String encode(List<ElevationSample> samples) => samples
      .map(
        (s) =>
            '${s.distanceM.toStringAsFixed(_decimals)},'
            '${s.altitudeM.toStringAsFixed(_decimals)}',
      )
      .join(';');

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
