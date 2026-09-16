import '../geo/lat_lng.dart';
import '../geo/projection.dart';
import 'local/database.dart';
import 'local/path_codec.dart';
import 'remote/overpass_client.dart';

export 'remote/overpass_client.dart' show TrailData, TrailSource;

/// One row of the treks list: a cached trail plus how far away it is from here.
///
/// [distanceM] is not stored — it depends on where you are standing, so it is computed per
/// query rather than cached alongside the route.
class TrailListing {
  final String id;
  final String name;
  final String kind;
  final double lengthM;
  final double distanceM;
  final List<LatLng> path;

  const TrailListing({
    required this.id,
    required this.name,
    required this.kind,
    required this.lengthM,
    required this.distanceM,
    required this.path,
  });
}

/// Nearby walking routes, cached.
///
/// The UI talks to this; it never touches the DAO or the HTTP client directly.
class TrailRepository {
  TrailRepository(this._db, this._source);

  final ClaimTrekDatabase _db;
  final TrailSource _source;

  /// Trails do not move. A week is long enough to make repeat visits free and short enough
  /// that a newly mapped route shows up in a reasonable time.
  static const Duration cacheTtl = Duration(days: 7);

  TrailDao get _trails => _db.trailDao;

  /// Trails near [centre], nearest trailhead first.
  ///
  /// Cache first, network second, and — when the network fails — a stale cache in preference
  /// to an error. Being out of signal is the normal condition for this feature, and yesterday's
  /// list beats an error screen. With nothing cached at all the failure is rethrown, because
  /// "you are offline" and "there are no trails here" need different screens.
  Future<List<TrailListing>> nearby(
    LatLng centre, {
    int radiusM = OverpassClient.defaultRadiusM,
  }) async {
    final cell = Projection.geohash5(centre);
    final fetchedAt = await _trails.cellFetchedAt(cell);

    if (fetchedAt != null && !_isStale(fetchedAt)) {
      return _listingsFromCache(cell, centre);
    }

    try {
      final fresh = await _source.fetchNearby(centre, radiusM: radiusM);
      await _trails.replaceCell(cell, [
        for (final trail in fresh) _toRow(trail, cell),
      ]);
      return _sorted([
        for (final trail in fresh) _toListing(trail, centre),
      ]);
    } catch (_) {
      // Stale beats nothing. Never cached at all is a genuine failure and stays one.
      if (fetchedAt == null) rethrow;
      return _listingsFromCache(cell, centre);
    }
  }

  /// Marks every cell stale. Backs a pull-to-refresh, and lets tests exercise expiry without
  /// waiting a week.
  Future<void> expireAll() => _trails.expireAllCells();

  bool _isStale(int fetchedAt) =>
      DateTime.now().millisecondsSinceEpoch - fetchedAt > cacheTtl.inMilliseconds;

  Future<List<TrailListing>> _listingsFromCache(
    String cell,
    LatLng centre,
  ) async {
    final rows = await _trails.getInCells([cell]);
    final out = <TrailListing>[];

    for (final row in rows) {
      final path = PathCodec.decode(row.encodedPath);
      // A row whose path will not decode is corrupt; dropping it costs one trail rather than
      // the whole list.
      if (path.isEmpty) continue;
      out.add(
        TrailListing(
          id: row.id,
          name: row.name,
          kind: row.kind,
          lengthM: row.lengthM,
          distanceM: Projection.haversine(centre, path.first),
          path: path,
        ),
      );
    }

    return _sorted(out);
  }

  Trail _toRow(TrailData trail, String cell) => Trail(
    id: trail.id,
    name: trail.name,
    kind: trail.kind,
    lengthM: trail.lengthM,
    encodedPath: PathCodec.encode(trail.path),
    geohash5: cell,
    cachedAt: DateTime.now().millisecondsSinceEpoch,
  );

  TrailListing _toListing(TrailData trail, LatLng centre) => TrailListing(
    id: trail.id,
    name: trail.name,
    kind: trail.kind,
    lengthM: trail.lengthM,
    distanceM: Projection.haversine(centre, trail.head),
    path: trail.path,
  );

  /// Nearest trailhead first: what matters in a list of treks is which one you could start.
  List<TrailListing> _sorted(List<TrailListing> trails) =>
      trails..sort((a, b) => a.distanceM.compareTo(b.distanceM));
}
