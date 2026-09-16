import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/local/path_codec.dart';
import 'package:claimtrek/data/player_identity.dart';
import 'package:claimtrek/data/territory_repository.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/geo/projection.dart';
import 'package:claimtrek/geo/territory_engine.dart';
import 'package:clipper2/clipper2.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const origin = LatLng(50.7217, 10.4483);

LatLng at(double eastM, double northM, [LatLng ref = origin]) =>
    Projection.unproject(PointD(eastM, northM), ref);

/// A densified rectangle in metres, so the ring looks like a track rather than four corners.
List<LatLng> rect(double e0, double n0, double e1, double n1) {
  final corners = <List<double>>[
    [e0, n0],
    [e1, n0],
    [e1, n1],
    [e0, n1],
  ];
  final out = <LatLng>[];
  for (var i = 0; i < corners.length; i++) {
    final a = corners[i];
    final b = corners[(i + 1) % corners.length];
    for (var s = 0; s < 8; s++) {
      final t = s / 8;
      out.add(at(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t));
    }
  }
  return out;
}

PathsD geometryOf(List<LatLng> track) =>
    TerritoryEngine.buildTerritoryGeographic(track, origin)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClaimTrekDatabase db;
  late TerritoryRepository repo;
  late PlayerIdentity player;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = ClaimTrekDatabase.forTesting(NativeDatabase.memory());
    player = await PlayerIdentity.load();
    repo = TerritoryRepository(db, player);
  });

  tearDown(() => db.close());

  /// Put a rival on the board without going through claim resolution.
  Future<void> giveRival(
    String id,
    List<LatLng> track, {
    bool verified = true,
  }) async {
    final geometry = geometryOf(track);
    await db.territoryDao.upsert(
      Territory(
        id: id,
        ownerId: 'rival-$id',
        ownerName: id,
        colorHex: '#2E86DE',
        wkt: TerritoryEngine.toWkt(geometry),
        areaM2: TerritoryEngine.areaM2(geometry),
        geohash5: Projection.geohash5(origin),
        refLat: origin.latitude,
        refLng: origin.longitude,
        claimedAt: 1,
        verified: verified,
      ),
    );
  }

  group('claim resolution', () {
    test('previewClaim reports the steal without writing anything', () async {
      await giveRival('mara', rect(0, 0, 100, 100));

      // Same size, shifted 50 m east: exactly half the rival's ground.
      final preview = await repo.previewClaim(geometryOf(rect(50, 0, 150, 100)));

      expect(preview.stolenAreaM2, closeTo(5000, 5));
      expect(preview.stolenFromCount, 1);

      // A discarded run must leave the world exactly as it found it.
      final rows = await db.territoryDao.getAll();
      expect(rows, hasLength(1));
      expect(rows.single.areaM2, closeTo(10000, 5));
    });

    test('commitClaim clips the rival and stores the claim', () async {
      await giveRival('mara', rect(0, 0, 100, 100));

      final outcome = await repo.commitClaim(
        claimGeographic: geometryOf(rect(50, 0, 150, 100)),
        reference: origin,
        verified: true,
      );

      expect(outcome.stolenAreaM2, closeTo(5000, 5));
      expect(outcome.stolenFromCount, 1);
      expect(outcome.areaM2, closeTo(10000, 5));

      final rows = await db.territoryDao.getAll();
      expect(rows, hasLength(2));

      final rival = rows.firstWhere((r) => r.id == 'mara');
      expect(rival.areaM2, closeTo(5000, 5), reason: 'the rival kept only what fell outside');

      final mine = rows.firstWhere((r) => r.ownerId == player.id);
      expect(mine.id, outcome.territoryId);
      expect(mine.verified, isTrue);
      expect(mine.geohash5, Projection.geohash5(origin));
      // The stored WKT must reload into the same ground.
      expect(
        TerritoryEngine.areaM2(TerritoryEngine.fromWkt(mine.wkt)!),
        closeTo(outcome.areaM2, 1),
      );
    });

    test('a rival reduced to a sliver is removed outright', () async {
      await giveRival('mara', rect(0, 0, 100, 100));

      // Swallow everything but a 0.2 m strip — about 20 m², below the 50 m² floor.
      await repo.commitClaim(
        claimGeographic: geometryOf(rect(0.2, -100, 300.2, 200)),
        reference: origin,
        verified: true,
      );

      final rows = await db.territoryDao.getAll();
      expect(rows.where((r) => r.id == 'mara'), isEmpty);
    });

    test('a claim that misses everything leaves rivals untouched', () async {
      await giveRival('mara', rect(0, 0, 100, 100));

      final outcome = await repo.commitClaim(
        claimGeographic: geometryOf(rect(5000, 0, 5100, 100)),
        reference: origin,
        verified: true,
      );

      expect(outcome.stolenAreaM2, 0);
      expect(outcome.stolenFromCount, 0);
      final rival = (await db.territoryDao.getAll()).firstWhere((r) => r.id == 'mara');
      expect(rival.areaM2, closeTo(10000, 5));
    });

    test('a second claim merges into one holding rather than stacking', () async {
      await repo.commitClaim(
        claimGeographic: geometryOf(rect(0, 0, 100, 100)),
        reference: origin,
        verified: true,
      );
      final second = await repo.commitClaim(
        claimGeographic: geometryOf(rect(50, 0, 150, 100)),
        reference: origin,
        verified: true,
      );

      final mine = (await db.territoryDao.getAll())
          .where((r) => r.ownerId == player.id)
          .toList();

      expect(mine, hasLength(1), reason: 'one runner reads as one holding');
      // 100x100 plus 100x100 overlapping by 50x100 = 15 000 m², not 20 000.
      expect(second.areaM2, closeTo(15000, 20));
      expect(
        second.stolenAreaM2,
        0,
        reason: 'a runner must never steal from themselves',
      );
    });
  });

  group('leaderboard', () {
    test('ranks by area and excludes unverified ground', () async {
      await giveRival('mara', rect(0, 0, 200, 200)); // 40 000
      await giveRival('jonas', rect(1000, 0, 1100, 100)); // 10 000
      await giveRival('vik', rect(2000, 0, 2300, 300), verified: false); // 90 000

      final board = await repo.watchLeaderboard().first;

      expect(board.map((e) => e.ownerName), ['mara', 'jonas']);
      expect(board.first.rank, 1);
      expect(board.first.totalAreaM2, closeTo(40000, 50));
      expect(board[1].rank, 2);
      expect(
        board.any((e) => e.ownerName == 'vik'),
        isFalse,
        reason: 'unverified ground is held and drawn, but does not score',
      );
    });

    test('marks the current player', () async {
      await repo.commitClaim(
        claimGeographic: geometryOf(rect(0, 0, 100, 100)),
        reference: origin,
        verified: true,
      );
      await giveRival('mara', rect(1000, 0, 1400, 400));

      final board = await repo.watchLeaderboard().first;
      expect(board.firstWhere((e) => e.isYou).ownerId, player.id);
      expect(board.where((e) => e.isYou), hasLength(1));
    });

    test('updates when a territory is written', () async {
      final seen = <int>[];
      final sub = repo.watchLeaderboard().listen((b) => seen.add(b.length));

      await giveRival('mara', rect(0, 0, 100, 100));
      await giveRival('jonas', rect(1000, 0, 1100, 100));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(seen.last, 2, reason: 'the stream must reflect writes as they land');
    });
  });

  group('rival seeding', () {
    test('seeds three rivals, one of them unverified', () async {
      await repo.seedRivalsAround(origin);

      final rows = await db.territoryDao.getAll();
      expect(rows, hasLength(3));
      expect(rows.map((r) => r.ownerName).toSet(), {'Mara', 'Jonas', 'Vik'});
      expect(
        rows.where((r) => !r.verified),
        hasLength(1),
        reason: 'one unverified rival makes the hatched style visible from first launch',
      );
      for (final row in rows) {
        expect(row.areaM2, greaterThan(1000));
        expect(TerritoryEngine.fromWkt(row.wkt), isNotNull);
      }
    });

    test('seeding is idempotent', () async {
      await repo.seedRivalsAround(origin);
      await repo.seedRivalsAround(at(5000, 5000));

      expect(await db.territoryDao.count(), 3);
    });
  });

  group('runs', () {
    test('a saved run round-trips its track', () async {
      final track = rect(0, 0, 100, 100);

      await repo.saveRun(
        id: 'run-1',
        title: 'Evening loop',
        isPublic: true,
        startedAt: 1700000000000,
        durationMs: 1800000,
        distanceM: 1257.4,
        steps: 1600,
        elevationGainM: 42.5,
        areaM2: 10000,
        verified: true,
        plausibleRatio: 0.97,
        reference: origin,
        track: track,
      );

      final stored = await db.runDao.byId('run-1');
      expect(stored, isNotNull);
      expect(stored!.title, 'Evening loop');
      expect(stored.distanceM, closeTo(1257.4, 0.001));
      expect(stored.refLat, closeTo(origin.latitude, 1e-9));

      final decoded = PathCodec.decode(stored.encodedPath);
      expect(decoded, hasLength(track.length));
      expect(decoded.first.latitude, closeTo(track.first.latitude, 1e-6));
    });

    test('renaming leaves the rest of the row alone', () async {
      await repo.saveRun(
        id: 'run-1',
        title: 'Untitled',
        isPublic: false,
        startedAt: 1,
        durationMs: 1,
        distanceM: 5,
        steps: 1,
        elevationGainM: 0,
        areaM2: 0,
        verified: true,
        plausibleRatio: 1,
        reference: origin,
        track: const [],
      );

      await db.runDao.rename('run-1', 'Morning loop', true);

      final stored = await db.runDao.byId('run-1');
      expect(stored!.title, 'Morning loop');
      expect(stored.isPublic, isTrue);
      expect(stored.distanceM, closeTo(5, 0.001));
    });
  });
}
