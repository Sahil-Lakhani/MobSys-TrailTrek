import '../../geo/lat_lng.dart';

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
