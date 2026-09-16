import 'dart:math' as math;

import 'package:clipper2/clipper2.dart';

import 'lat_lng.dart';

/// Local planar projection: latitude/longitude to metres, relative to a reference point.
///
/// Every piece of geometry in the app happens in this metre space, never in degrees. That is
/// the whole reason a geometry's area can be read straight off as square metres. Over the few
/// kilometres a run covers, the flat-earth error is well under a metre.
class Projection {
  Projection._();

  static const double metresPerDegreeLat = 111320.0;
  static const double _earthRadiusM = 6371008.8;

  static double _radians(double degrees) => degrees * math.pi / 180.0;

  static double _degrees(double radians) => radians * 180.0 / math.pi;

  static double metresPerDegreeLon(double refLatitude) =>
      metresPerDegreeLat * math.cos(_radians(refLatitude));

  /// Geographic point -> metres east/north of [ref].
  ///
  /// Returns clipper2's [PointD] rather than a type of our own: the geometry engine speaks in
  /// `PointD`, and an extra wrapper would buy nothing but a conversion on every vertex of
  /// every ring.
  static PointD project(LatLng p, LatLng ref) => PointD(
    (p.longitude - ref.longitude) * metresPerDegreeLon(ref.latitude),
    (p.latitude - ref.latitude) * metresPerDegreeLat,
  );

  /// Metres east/north of [ref] -> geographic point.
  static LatLng unproject(PointD c, LatLng ref) => LatLng(
    ref.latitude + c.y / metresPerDegreeLat,
    ref.longitude + c.x / metresPerDegreeLon(ref.latitude),
  );

  /// Great-circle distance in metres.
  static double haversine(LatLng a, LatLng b) {
    final dLat = _radians(b.latitude - a.latitude);
    final dLon = _radians(b.longitude - a.longitude);
    final lat1 = _radians(a.latitude);
    final lat2 = _radians(b.latitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1) *
            math.cos(lat2);
    return 2 * _earthRadiusM * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  /// Initial bearing from [a] to [b], degrees clockwise from true north, 0..360.
  static double bearing(LatLng a, LatLng b) {
    final lat1 = _radians(a.latitude);
    final lat2 = _radians(b.latitude);
    final dLon = _radians(b.longitude - a.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final deg = _degrees(math.atan2(y, x));
    return (deg + 360.0) % 360.0;
  }

  /// Total travelled distance along a track, in metres.
  static double pathLength(List<LatLng> track) {
    var total = 0.0;
    for (var i = 0; i + 1 < track.length; i++) {
      total += haversine(track[i], track[i + 1]);
    }
    return total;
  }

  /// A ~5 km geohash cell used as a cheap "is this nearby" key.
  ///
  /// Document stores cannot do geo-queries, so nearby territories
  /// are fetched by prefix instead. Still the right index even while storage is local.
  static String geohash5(LatLng p) => geohash(p, 5);

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String geohash(LatLng p, int precision) {
    var latMin = -90.0, latMax = 90.0;
    var lonMin = -180.0, lonMax = 180.0;
    final out = StringBuffer();
    var bit = 0;
    var index = 0;
    var even = true;

    while (out.length < precision) {
      if (even) {
        final mid = (lonMin + lonMax) / 2;
        if (p.longitude > mid) {
          index = index * 2 + 1;
          lonMin = mid;
        } else {
          index *= 2;
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (p.latitude > mid) {
          index = index * 2 + 1;
          latMin = mid;
        } else {
          index *= 2;
          latMax = mid;
        }
      }
      even = !even;
      if (bit < 4) {
        bit++;
      } else {
        out.write(_base32[index]);
        bit = 0;
        index = 0;
      }
    }
    return out.toString();
  }
}
