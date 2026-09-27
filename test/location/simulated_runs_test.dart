import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/player_identity.dart';
import 'package:claimtrek/data/territory_repository.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/geo/loop_detector.dart';
import 'package:claimtrek/geo/projection.dart';
import 'package:claimtrek/geo/territory_engine.dart';
import 'package:claimtrek/location/simulated_runs.dart';
import 'package:clipper2/clipper2.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const runner = LatLng(50.7217, 10.4483);

LatLng at(double e, double n) => Projection.unproject(PointD(e, n), runner);

/// A square plot, [size] metres a side, with its south-west corner at (e, n).
PathsD plot(double e, double n, double size) {
  final ring = <LatLng>[];
  final corners = [
    [e, n],
    [e + size, n],
    [e + size, n + size],
    [e, n + size],
  ];
  for (var i = 0; i < 4; i++) {
    final a = corners[i], b = corners[(i + 1) % 4];
    for (var s = 0; s < 8; s++) {
      final t = s / 8;
      ring.add(at(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t));
    }
  }
  return TerritoryEngine.buildTerritoryGeographic(ring, runner)!;
}

List<LatLng> trackOf(SimulatedRun run) => [for (final p in run.points) p.point];

void main() {
  group('capture test', () {
    test('runs a loop the detector will close', () {
      final run = SimulatedRuns.capture(runner: runner, existing: const []);
      final track = trackOf(run);

      expect(track.length, greaterThanOrEqualTo(LoopDetector.minPoints));
      expect(LoopDetector.isClosed(track), isTrue);
    });

    test('takes empty ground rather than re-claiming a plot', () {
      // Ground already held due north, where the first candidate would land.
      final taken = plot(-150, 200, 300);
      final run = SimulatedRuns.capture(runner: runner, existing: [taken]);
      final claim = TerritoryEngine.buildTerritoryGeographic(
        trackOf(run),
        runner,
      )!;

      expect(TerritoryEngine.intersect(claim, taken), isEmpty);
      expect(
        TerritoryEngine.areaM2(claim),
        closeTo(SimulatedRuns.captureSideM * SimulatedRuns.captureSideM, 300),
      );
    });

    test(
      'points are timed at a running pace, so the GPS gate lets them through',
      () {
        final run = SimulatedRuns.capture(runner: runner, existing: const []);
        for (var i = 1; i < run.points.length; i++) {
          final a = run.points[i - 1], b = run.points[i];
          final seconds = b.time!.difference(a.time!).inMilliseconds / 1000;
          final metres = Projection.haversine(a.point, b.point);
          expect(metres / seconds, lessThan(4), reason: 'leg $i');
        }
      },
    );
  });

  group('steal test', () {
    test('has nothing to do with no rival on the map', () {
      expect(SimulatedRuns.steal(runner: runner, rivals: const []), isNull);
    });

    test('goes after the nearest rival', () {
      final run = SimulatedRuns.steal(
        runner: runner,
        rivals: [
          PlannedRival(
            ownerId: 'far',
            ownerName: 'Far',
            geometry: plot(2000, 0, 200),
          ),
          PlannedRival(
            ownerId: 'near',
            ownerName: 'Mara',
            geometry: plot(300, 0, 200),
          ),
        ],
      )!;

      expect(run.description, contains('Mara'));
      expect(LoopDetector.isClosed(trackOf(run)), isTrue);
    });

    test(
      'saved, it takes about half the rival plot and keeps the rest theirs',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});
        final db = ClaimTrekDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = TerritoryRepository(db, await PlayerIdentity.load());

        final rivalGround = plot(300, 0, 200);
        await db.territoryDao.upsert(
          Territory(
            id: 'mara',
            ownerId: 'rival-mara',
            ownerName: 'Mara',
            colorHex: '#2E86DE',
            wkt: TerritoryEngine.toWkt(rivalGround),
            areaM2: TerritoryEngine.areaM2(rivalGround),
            geohash5: Projection.geohash5(runner),
            refLat: runner.latitude,
            refLng: runner.longitude,
            claimedAt: 1,
            verified: true,
            rev: 1,
            dirty: false,
          ),
        );

        final run = SimulatedRuns.steal(
          runner: runner,
          rivals: [
            PlannedRival(
              ownerId: 'rival-mara',
              ownerName: 'Mara',
              geometry: rivalGround,
            ),
          ],
        )!;
        final outcome = await repo.commitClaim(
          claimGeographic: TerritoryEngine.buildTerritoryGeographic(
            trackOf(run),
            runner,
          )!,
          reference: runner,
          verified: false,
        );

        expect(outcome.stolenFromCount, 1);
        expect(
          outcome.stolenAreaM2,
          closeTo(20000, 800),
          reason: 'half of 200 x 200 m',
        );
        final mara = (await db.territoryDao.getAll()).firstWhere(
          (t) => t.id == 'mara',
        );
        expect(mara.areaM2, closeTo(20000, 800));
        expect(mara.dirty, isTrue, reason: 'the loss goes up to the rival too');
        // And the runner gained more than was taken: the loop wraps open ground as well.
        expect(outcome.areaM2, greaterThan(outcome.stolenAreaM2));
      },
    );
  });
}
