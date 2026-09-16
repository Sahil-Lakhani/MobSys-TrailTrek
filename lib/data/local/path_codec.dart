import '../../geo/lat_lng.dart';

/// Track <-> string, so a run's path lives in one text column instead of a join table with a
/// row per GPS fix. Six decimals is about 10 cm, well past what the receiver can resolve.
class PathCodec {
  PathCodec._();

  static const int _decimals = 6;

  static String encode(List<LatLng> points) => points
      .map(
        (p) =>
            '${p.latitude.toStringAsFixed(_decimals)},'
            '${p.longitude.toStringAsFixed(_decimals)}',
      )
      .join(';');

  /// Skips malformed pairs rather than throwing or returning null: a single corrupt vertex
  /// should cost one point of a track, not the whole run.
  static List<LatLng> decode(String encoded) {
    if (encoded.trim().isEmpty) return const [];

    final out = <LatLng>[];
    for (final pair in encoded.split(';')) {
      final parts = pair.split(',');
      if (parts.length != 2) continue;
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat == null || lng == null) continue;
      out.add(LatLng(lat, lng));
    }
    return out;
  }
}
