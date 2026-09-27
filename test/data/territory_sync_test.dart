import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/model/models.dart';
import 'package:claimtrek/data/player_identity.dart';
import 'package:claimtrek/data/remote/territory_store.dart';
import 'package:claimtrek/data/territory_repository.dart';
import 'package:claimtrek/data/territory_sync.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/geo/projection.dart';
import 'package:claimtrek/geo/territory_engine.dart';
import 'package:clipper2/clipper2.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const origin = LatLng(50.7217, 10.4483);

LatLng at(double eastM, double northM) =>
    Projection.unproject(PointD(eastM, northM), origin);

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

class Device {
  Device._(this.db, this.player, this.repo, this.sync);

  final ClaimTrekDatabase db;
  final PlayerIdentity player;
  final TerritoryRepository repo;
  final TerritorySync sync;
  int ownGroundChanges = 0;

  static Future<Device> create(
    FakeFirebaseFirestore firestore, {
    String? uid,
    String name = 'Runner',
  }) async {
    final db = ClaimTrekDatabase.forTesting(NativeDatabase.memory());
    final player = await PlayerIdentity.load();
    if (uid != null) player.bindTo(uid: uid, displayName: name, photoUrl: null);
    final repo = TerritoryRepository(db, player);
    late Device device;
    final sync = TerritorySync(
      db,
      TerritoryStore(firestore),
      player,
      onOwnGroundChanged: () async => device.ownGroundChanges++,
    );
    device = Device._(db, player, repo, sync);
    return device;
  }

  Future<ClaimOutcome> claim(List<LatLng> track) => repo.commitClaim(
    claimGeographic: geometryOf(track),
    reference: origin,
    verified: true,
  );

  Future<List<Territory>> live() => db.territoryDao.getAll();

  Future<void> close() async {
    sync.dispose();
    await db.close();
  }
}

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  final devices = <Device>[];

  Future<Device> device({String? uid, String name = 'Runner'}) async {
    final d = await Device.create(firestore, uid: uid, name: name);
    devices.add(d);
    return d;
  }

  Future<Map<String, dynamic>?> doc(String id) async =>
      (await firestore.collection(TerritoryStore.collection).doc(id).get())
          .data();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
  });

  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
  });

  group('publishing', () {
    test(
      'a claim goes up once flushed, and the row is marked published',
      () async {
        final a = await device(uid: 'uid-a', name: 'Ana');
        final outcome = await a.claim(rect(0, 0, 100, 100));

        expect((await a.db.territoryDao.getDirty()), hasLength(1));
        await a.sync.flush();

        final published = await doc(outcome.territoryId);
        expect(published, isNotNull);
        expect(published!['ownerId'], 'uid-a');
        expect(published['ownerName'], 'Ana');
        expect(published['areaM2'], closeTo(10000, 50));
        expect(
          published['cells'],
          contains(Projection.geohash5(origin)),
          reason: 'the cell index is what lets nearby players find it',
        );
        expect(await a.db.territoryDao.getDirty(), isEmpty);
      },
    );

    test('signed out, nothing leaves the phone and the claim waits', () async {
      final solo = await device();
      final outcome = await solo.claim(rect(0, 0, 100, 100));

      await solo.sync.flush();

      expect(await doc(outcome.territoryId), isNull);
      expect(await solo.db.territoryDao.getDirty(), hasLength(1));
    });

    test('the stand-in rivals never leave the device', () async {
      final a = await device(uid: 'uid-a');
      await a.repo.seedRivalsAround(origin);
      await a.claim(rect(-400, -400, 400, 400));

      await a.sync.flush();

      final all = await firestore.collection(TerritoryStore.collection).get();
      expect(all.docs.where((d) => d.id.startsWith('seed-')), isEmpty);
      expect(await a.db.territoryDao.getDirty(), isEmpty);
    });

    test('a claim made offline goes up on a later flush', () async {
      final a = await device(uid: 'uid-a');
      final outcome = await a.claim(rect(0, 0, 100, 100));

      expect(await doc(outcome.territoryId), isNull);

      await a.sync.flush();
      expect(await doc(outcome.territoryId), isNotNull);
    });

    test(
      'merging into your own ground removes the old plot for everyone',
      () async {
        final a = await device(uid: 'uid-a');
        final first = await a.claim(rect(0, 0, 100, 100));
        await a.sync.flush();

        final second = await a.claim(rect(50, 0, 150, 100));
        await a.sync.flush();

        expect((await doc(first.territoryId))!['areaM2'], 0);
        expect((await doc(second.territoryId))!['areaM2'], closeTo(15000, 80));
        expect(await a.live(), hasLength(1));
      },
    );
  });

  group('between players', () {
    test("a rival's ground appears on the map around you", () async {
      final a = await device(uid: 'uid-a', name: 'Ana');
      await a.claim(rect(0, 0, 100, 100));
      await a.sync.flush();

      final b = await device(uid: 'uid-b', name: 'Ben');
      b.sync.follow(origin);
      await settle();

      final seen = await b.live();
      expect(seen, hasLength(1));
      expect(seen.single.ownerId, 'uid-a');
      expect(seen.single.ownerName, 'Ana');
      expect(seen.single.dirty, isFalse);
    });

    test(
      'stealing reaches the owner, and their standing is restated',
      () async {
        final a = await device(uid: 'uid-a');
        final plot = await a.claim(rect(0, 0, 100, 100));
        await a.sync.flush();
        a.sync.follow(origin);

        final b = await device(uid: 'uid-b');
        b.sync.follow(origin);
        await settle();

        final steal = await b.claim(rect(50, -20, 170, 120));
        expect(steal.stolenAreaM2, closeTo(5000, 60));
        await b.sync.flush();
        await settle();

        expect((await doc(plot.territoryId))!['areaM2'], closeTo(5000, 60));

        final anas = (await a.live()).firstWhere((t) => t.ownerId == 'uid-a');
        expect(anas.areaM2, closeTo(5000, 60));
        expect(a.ownGroundChanges, greaterThan(0));

        expect((await a.live()).any((t) => t.ownerId == 'uid-b'), isTrue);
      },
    );

    test(
      'two players stealing from one plot at once both keep their bite',
      () async {
        final a = await device(uid: 'uid-a');
        final plot = await a.claim(rect(0, 0, 300, 100));
        await a.sync.flush();

        final b = await device(uid: 'uid-b');
        final c = await device(uid: 'uid-c');
        b.sync.follow(origin);
        c.sync.follow(origin);
        await settle();

        await b.claim(rect(-20, -20, 100, 120));
        await c.claim(rect(200, -20, 320, 120));
        await b.sync.flush();
        await c.sync.flush();
        await settle();

        expect((await doc(plot.territoryId))!['areaM2'], closeTo(10000, 120));

        for (final d in [b, c]) {
          final anas = (await d.live()).firstWhere(
            (t) => t.id == plot.territoryId,
          );
          expect(anas.areaM2, closeTo(10000, 120));
        }
      },
    );

    test('ground taken entirely disappears from the owner too', () async {
      final a = await device(uid: 'uid-a');
      final plot = await a.claim(rect(0, 0, 100, 100));
      await a.sync.flush();
      a.sync.follow(origin);

      final b = await device(uid: 'uid-b');
      b.sync.follow(origin);
      await settle();

      await b.claim(rect(-30, -30, 130, 130));
      await b.sync.flush();
      await settle();

      expect((await doc(plot.territoryId))!['areaM2'], 0);
      expect((await a.live()).where((t) => t.id == plot.territoryId), isEmpty);
    });

    test(
      'a steal made offline still lands after the owner shrank elsewhere',
      () async {
        final a = await device(uid: 'uid-a');
        final plot = await a.claim(rect(0, 0, 300, 100));
        await a.sync.flush();

        final b = await device(uid: 'uid-b');
        final c = await device(uid: 'uid-c');
        b.sync.follow(origin);
        c.sync.follow(origin);
        await settle();

        await b.claim(rect(-20, -20, 100, 120));
        await c.claim(rect(200, -20, 320, 120));
        await c.sync.flush();
        await settle();

        final merged = (await b.db.territoryDao.byId(plot.territoryId))!;
        expect(merged.areaM2, closeTo(10000, 120));
        expect(merged.dirty, isTrue);

        await b.sync.flush();
        expect((await doc(plot.territoryId))!['areaM2'], closeTo(10000, 120));
      },
    );
  });

  group('untrusted documents', () {
    test('a document without an owner is ignored', () {
      expect(
        TerritoryStore.decode('x', {'wkt': 'POLYGON((0 0,1 0,1 1,0 0))'}),
        isNull,
      );
    });

    test('geometry that will not parse is ignored rather than treated as a removal', () {
      expect(
        TerritoryStore.decode('x', {
          'ownerId': 'u',
          'wkt': 'not wkt',
          'rev': 3,
        }),
        isNull,
      );
    });

    test('an oversized geometry is refused', () {
      expect(
        TerritoryStore.decode('x', {
          'ownerId': 'u',
          'wkt': 'P' * (TerritoryStore.maxWktLength + 1),
        }),
        isNull,
      );
    });

    test('the area is measured, not taken on the writer\'s word', () {
      final wkt = TerritoryEngine.toWkt(geometryOf(rect(0, 0, 100, 100)));
      final decoded = TerritoryStore.decode('x', {
        'ownerId': 'u',
        'wkt': wkt,
        'areaM2': 99999999,
        'colorHex': 'javascript:alert(1)',
      })!;

      expect(decoded.areaM2, closeTo(10000, 50));
      expect(decoded.colorHex, '#FF6B35', reason: 'a bad colour falls back');
    });
  });

  group('reconciling with the server', () {
    test('a rival plot the server no longer has is let go', () async {
      final b = await device(uid: 'uid-b');
      await b.db.territoryDao.upsert(
        Territory(
          id: 'ghost',
          ownerId: 'uid-z',
          ownerName: 'Zed',
          colorHex: '#2E86DE',
          wkt: TerritoryEngine.toWkt(geometryOf(rect(0, 0, 100, 100))),
          areaM2: 10000,
          geohash5: Projection.geohash5(origin),
          refLat: origin.latitude,
          refLng: origin.longitude,
          claimedAt: 1,
          verified: true,
          rev: 2,
          dirty: false,
        ),
      );

      b.sync.follow(origin);
      await settle();

      expect(await b.db.territoryDao.byId('ghost'), isNull);
    });

    test(
      'your own ground missing from the server is sent back up, not deleted',
      () async {
        final a = await device(uid: 'uid-a');
        final plot = await a.claim(rect(0, 0, 100, 100));
        final row = (await a.db.territoryDao.byId(plot.territoryId))!;
        await a.db.territoryDao.upsert(row.copyWith(dirty: false));

        a.sync.follow(origin);
        await settle();
        await a.sync.flush();

        expect(await a.db.territoryDao.byId(plot.territoryId), isNotNull);
        expect(await doc(plot.territoryId), isNotNull);
      },
    );
  });

  test(
    'clearing the upload flag never swallows a change made mid-upload',
    () async {
      final a = await device(uid: 'uid-a');
      final plot = await a.claim(rect(0, 0, 100, 100));
      final row = (await a.db.territoryDao.byId(plot.territoryId))!;

      await a.db.territoryDao.upsert(row.copyWith(rev: row.rev + 1));

      final cleared = await a.db.territoryDao.markPublished(
        row.id,
        expectedRev: row.rev,
        newRev: row.rev,
      );
      expect(cleared, isFalse);
      expect((await a.db.territoryDao.byId(row.id))!.dirty, isTrue);
    },
  );
}
