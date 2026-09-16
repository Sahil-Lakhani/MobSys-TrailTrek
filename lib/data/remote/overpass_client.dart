import 'package:dio/dio.dart';

import '../../geo/lat_lng.dart';
import '../../geo/projection.dart';

/// One named walking route, as Overpass describes it and before it is cached.
///
/// Not the Drift `Trail` row: that carries an encoded path and a cache timestamp, which are
/// storage concerns. This is what came off the wire.
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

  /// Where the route starts, for "how far away is this".
  LatLng get head => path.first;
}

/// Where trails come from.
///
/// Exists so [TrailRepository] can be tested against a fake that counts calls — "did this hit
/// the network again?" is the single most important question about a cache, and it cannot be
/// asked of a concrete HTTP client.
abstract interface class TrailSource {
  Future<List<TrailData>> fetchNearby(LatLng centre, {int radiusM});
}

/// Nearby walking routes from OpenStreetMap.
///
/// Queries *relations* tagged `route=hiking|foot` rather than ways tagged `highway=path`. Ways
/// give far more results, but they arrive unnamed and fragmented — a single trail split into
/// forty pieces called "Path" — and a list the user cannot read is not a feature.
class OverpassClient implements TrailSource {
  OverpassClient(this._dio);

  final Dio _dio;

  static const String endpoint = 'https://overpass-api.de/api/interpreter';

  /// Overpass answers **HTTP 406 to default HTTP-client User-Agents**, as does the OSM tile
  /// server. This is not optional politeness; without it nothing works.
  static const String userAgent = 'ClaimTrek/1.0 (github.com/claimtrek)';

  static const int defaultRadiusM = 5000;

  /// `out geom` inlines each member way's vertices, so one request returns drawable routes.
  /// Without it the response is bare member ids and every route needs a second query.
  static String buildQuery(LatLng centre, {int radiusM = defaultRadiusM}) {
    final lat = centre.latitude;
    final lng = centre.longitude;
    return '[out:json][timeout:25];'
        '(relation["route"~"^(hiking|foot)\$"](around:$radiusM,$lat,$lng););'
        'out geom;';
  }

  /// Throws [DioException] on transport failure so the caller can distinguish "offline" and
  /// "rate-limited" from "there is genuinely nothing here". Collapsing those into an empty list
  /// would show a user with no signal the same empty screen as a user in a city with no trails.
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

  /// Kept separate from the request so it can be tested against a recorded response with no
  /// network at all — which is the only way to have a regression test for a free public API
  /// that rate-limits.
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
      // An unnamed route is dropped outright. Every row in the list should be something the
      // user could recognise on a signpost.
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

  /// Chains member ways into a single path by their shared endpoints.
  ///
  /// A route relation's members are not stored in walking order, and many are reversed relative
  /// to the direction of travel. Concatenating them as they arrive draws long straight chords
  /// across the map between the end of one way and the start of an unrelated one, and inflates
  /// the reported length by the sum of those chords — Rundweg 7 measured 29.8 km that way.
  ///
  /// Ways in a relation share exact node coordinates, so endpoints are matched exactly rather
  /// than within a tolerance. Members that cannot be chained onto either end are dropped: they
  /// are usually approach spurs or signed variants, and drawing them would put the phantom
  /// chords straight back.
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

  /// Each member's own vertices, in the order Overpass gave them.
  ///
  /// Members without geometry — a guidepost node, a role we did not ask for — are skipped
  /// rather than treated as a break in the route.
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
