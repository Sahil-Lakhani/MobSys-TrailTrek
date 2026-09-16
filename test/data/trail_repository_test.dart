import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/trail_repository.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/geo/projection.dart';
import 'package:clipper2/clipper2.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const centre = LatLng(50.7217, 10.4483);

LatLng at(double eastM, double northM) =>
    Projection.unproject(PointD(eastM, northM), centre);

TrailData trail(String id, String name, List<LatLng> path) => TrailData(
  id: id,
  name: name,
  kind: 'hiking',
  lengthM: Projection.pathLength(path),
  path: path,
);

/// Stands in for Overpass. Counts calls, so "did this hit the network again?" is a
/// question the tests can actually ask.
class FakeSource implements TrailSource {
  FakeSource(this._result);

  List<TrailData> _result;
  int calls = 0;
  Object? throws;

  set result(List<TrailData> value) => _result = value;

  @override
  Future<List<TrailData>> fetchNearby(LatLng centre, {int radiusM = 5000}) async {
    calls++;
    final error = throws;
    if (error != null) throw error;
    return _result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClaimTrekDatabase db;
  late FakeSource source;
  late TrailRepository repo;

  final near = trail('relation/1', 'Near Way', [at(0, 0), at(0, 300)]);
  final far = trail('relation/2', 'Far Way', [at(2000, 0), at(2000, 400)]);

  setUp(() {
    db = ClaimTrekDatabase.forTesting(NativeDatabase.memory());
    source = FakeSource([far, near]);
    repo = TrailRepository(db, source);
  });

  tearDown(() => db.close());

  test('fetches, then serves the second call from cache', () async {
    await repo.nearby(centre);
    await repo.nearby(centre);

    expect(source.calls, 1, reason: 'Overpass rate-limits; one query per cell');
  });

  test('sorts by distance to the trailhead, nearest first', () async {
    final trails = await repo.nearby(centre);

    expect(trails.map((t) => t.name), ['Near Way', 'Far Way']);
    expect(trails.first.distanceM, lessThan(trails.last.distanceM));
  });

  test('keeps the real length, which is not the distance away', () async {
    final trails = await repo.nearby(centre);

    expect(trails.first.lengthM, closeTo(300.0, 1.0));
    expect(trails.last.lengthM, closeTo(400.0, 1.0));
  });

  test('the cached path survives the round trip through storage', () async {
    await repo.nearby(centre);
    final fromCache = await repo.nearby(centre);

    expect(fromCache.first.path.length, 2);
    expect(fromCache.first.path.first.latitude, closeTo(at(0, 0).latitude, 1e-6));
  });

  test('a stale cache is refetched', () async {
    await repo.nearby(centre);
    await repo.expireAll();
    await repo.nearby(centre);

    expect(source.calls, 2);
  });

  test('a network failure falls back to a stale cache rather than an error', () async {
    // Being offline on a hilltop is the normal case for this feature. Yesterday's trail list
    // is far more useful than an error screen.
    await repo.nearby(centre);
    await repo.expireAll();
    source.throws = Exception('offline');

    final trails = await repo.nearby(centre);

    expect(trails.map((t) => t.name), ['Near Way', 'Far Way']);
  });

  test('a network failure with nothing cached rethrows', () async {
    // Distinguishable from "no trails here": the UI must offer retry, not an empty state.
    source.throws = Exception('offline');

    expect(() => repo.nearby(centre), throwsA(isA<Exception>()));
  });

  test('an empty result is cached, so an empty area is not re-queried', () async {
    source.result = const [];

    expect(await repo.nearby(centre), isEmpty);
    expect(await repo.nearby(centre), isEmpty);
    expect(source.calls, 1);
  });
}
