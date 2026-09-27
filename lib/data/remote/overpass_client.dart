import 'package:dio/dio.dart';

import '../../geo/lat_lng.dart';
import '../../geo/projection.dart';

class TrailData {
  final String id;
  final String name;
  final String kind;
  final double lengthM;
  final List<LatLng> path;

  const TrailData({
    required this.id,
    required this.name,
    required this.kind,
    required this.lengthM,
    required this.path,
  });

  LatLng get head => path.first;
}

abstract interface class TrailSource {
  Future<List<TrailData>> fetchNearby(LatLng centre, {int radiusM});
}

class OverpassClient implements TrailSource {
  OverpassClient(this._dio);

  final Dio _dio;

  static const String endpoint = 'https://overpass-api.de/api/interpreter';

  static const String userAgent = 'ClaimTrek/1.0 (github.com/claimtrek)';

  static const int defaultRadiusM = 5000;

  static String buildQuery(LatLng centre, {int radiusM = defaultRadiusM}) {
    final lat = centre.latitude;
    final lng = centre.longitude;
    return '[out:json][timeout:25];'
        '(relation["route"~"^(hiking|foot)\$"](around:$radiusM,$lat,$lng););'
        'out geom;';
  }

  @override
  Future<List<TrailData>> fetchNearby(
    LatLng centre, {
    int radiusM = defaultRadiusM,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      endpoint,
      data: buildQuery(centre, radiusM: radiusM),
      options: Options(
        headers: const {'User-Agent': userAgent},
        contentType: Headers.textPlainContentType,
        responseType: ResponseType.json,
      ),
    );

    final body = response.data;
    return body == null ? const [] : parse(body);
  }

  static List<TrailData> parse(Map<String, dynamic> body) {
    final elements = body['elements'];
    if (elements is! List) return const [];

    final out = <TrailData>[];

    for (final element in elements) {
      if (element is! Map) continue;
      if (element['type'] != 'relation') continue;

      final tags = element['tags'];
      if (tags is! Map) continue;

      final name = tags['name'];
      final kind = tags['route'];
      if (name is! String || name.trim().isEmpty) continue;
      if (kind is! String) continue;

      final path = _joinMembers(element['members']);
      if (path.length < 2) continue;

      out.add(
        TrailData(
          id: 'relation/${element['id']}',
          name: name.trim(),
          kind: kind,
          lengthM: Projection.pathLength(path),
          path: path,
        ),
      );
    }

    return out;
  }

  static List<LatLng> _joinMembers(Object? members) {
    final ways = _memberGeometries(members);
    if (ways.isEmpty) return const [];

    final path = List<LatLng>.from(ways.removeAt(0));

    var joined = true;
    while (ways.isNotEmpty && joined) {
      joined = false;
      for (var i = 0; i < ways.length; i++) {
        final way = ways[i];

        if (way.first == path.last) {
          path.addAll(way.skip(1));
        } else if (way.last == path.last) {
          path.addAll(way.reversed.skip(1));
        } else if (way.last == path.first) {
          path.insertAll(0, way.take(way.length - 1));
        } else if (way.first == path.first) {
          path.insertAll(0, way.reversed.take(way.length - 1));
        } else {
          continue;
        }

        ways.removeAt(i);
        joined = true;
        break;
      }
    }

    return path;
  }

  static List<List<LatLng>> _memberGeometries(Object? members) {
    if (members is! List) return const [];

    final ways = <List<LatLng>>[];

    for (final member in members) {
      if (member is! Map) continue;
      final geometry = member['geometry'];
      if (geometry is! List) continue;

      final way = <LatLng>[];
      for (final vertex in geometry) {
        if (vertex is! Map) continue;
        final lat = vertex['lat'];
        final lon = vertex['lon'];
        if (lat is! num || lon is! num) continue;

        final point = LatLng(lat.toDouble(), lon.toDouble());
        if (way.isNotEmpty && way.last == point) continue;
        way.add(point);
      }

      if (way.length >= 2) ways.add(way);
    }

    return ways;
  }
}
