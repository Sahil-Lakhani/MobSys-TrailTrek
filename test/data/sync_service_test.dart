import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/player_identity.dart';
import 'package:claimtrek/data/remote/firestore_mirror.dart';
import 'package:claimtrek/data/sync_service.dart';
import 'package:claimtrek/data/territory_repository.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:claimtrek/geo/projection.dart';
import 'package:claimtrek/geo/territory_engine.dart';
import 'package:clipper2/clipper2.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const origin = LatLng(50.7217, 10.4483);

LatLng at(double e, double n) => Projection.unproject(PointD(e, n), origin);

List<LatLng> square(double size) {
  final out = <LatLng>[];
  final corners = [
    [0.0, 0.0],
    [size, 0.0],
    [size, size],
    [0.0, size],
  ];
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClaimTrekDatabase db;
  late TerritoryRepository repo;
  late PlayerIdentity player;
  late FakeFirebaseFirestore firestore;
  late SyncService sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = ClaimTrekDatabase.forTesting(NativeDatabase.memory());
    player = await PlayerIdentity.load();
    repo = TerritoryRepository(db, player);
    firestore = FakeFirebaseFirestore();
    sync = SyncService(repo, FirestoreMirror(firestore), player);
  });

  tearDown(() => db.close());

  Future<Run> saveARun() => repo.saveRun(
    id: 'run-1',
    title: 'Afternoon run',
    isPublic: false,
    startedAt: 1758620000000,
    durationMs: 41000,
    distanceM: 1253,
    steps: 812,
    elevationGainM: 167,
    areaM2: 10000,
    verified: true,
    plausibleRatio: 1,
    reference: origin,
    track: square(100),
  );

  Future<void> claim() => repo.commitClaim(
    claimGeographic: TerritoryEngine.buildTerritoryGeographic(square(100), origin)!,
    reference: origin,
    verified: true,
  );

  test('signed out, nothing leaves the device', () async {
    // The game is fully playable without an account, and a player who has not signed in has
    // not agreed to publish their GPS track anywhere.
    final run = await saveARun();
    await sync.onRunSaved(run);

    expect((await firestore.collection('runs').get()).docs, isEmpty);
    expect((await firestore.collection('users').get()).docs, isEmpty);
  });

  test('signed in, a saved run is mirrored under the account', () async {
    player.bindTo(uid: 'uid-a', displayName: 'Sahil', photoUrl: null);

    final run = await saveARun();
    await sync.onRunSaved(run);

    final doc = (await firestore.collection('runs').doc('run-1').get()).data();
    expect(doc, isNotNull);
    expect(doc!['ownerId'], 'uid-a');
    expect(doc['title'], 'Afternoon run');
    expect(doc['distanceM'], closeTo(1253, 1e-9));
  });

  test('saving a run republishes the standing', () async {
    player.bindTo(uid: 'uid-a', displayName: 'Sahil', photoUrl: null);
    await claim();

    final run = await saveARun();
    await sync.onRunSaved(run);

    final doc = (await firestore.collection('users').doc('uid-a').get()).data();
    expect(doc!['totalAreaM2'], closeTo(10000, 50));
    expect(doc['displayName'], 'Sahil');
  });

  test('signing in adopts the ground and publishes it', () async {
    await claim();
    final localId = player.localId;

    player.bindTo(uid: 'uid-a', displayName: 'Sahil', photoUrl: null);
    await sync.onSignedIn(previousOwnerId: localId);

    expect((await db.territoryDao.getAll()).single.ownerId, 'uid-a');
    final doc = (await firestore.collection('users').doc('uid-a').get()).data();
    expect(doc!['totalAreaM2'], closeTo(10000, 50));
  });

  test('a failed mirror costs the upload, never the run', () async {
    // The local save has already committed by the time sync runs. If the network write throws,
    // swallowing it loses a leaderboard update; letting it escape would surface as the run
    // itself having failed, which it did not.
    player.bindTo(uid: 'uid-a', displayName: 'Sahil', photoUrl: null);
    final failing = SyncService(repo, _ExplodingMirror(), player);

    final run = await saveARun();

    await expectLater(failing.onRunSaved(run), completes);
    expect(await db.runDao.byId('run-1'), isNotNull);
  });
}

class _ExplodingMirror implements FirestoreMirror {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<void>.error(StateError('network is down'));
}
