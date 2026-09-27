import 'dart:io';

import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/photos/run_photo_store.dart';
import 'package:claimtrek/data/photos/run_photos.dart';
import 'package:claimtrek/data/player_identity.dart';
import 'package:claimtrek/data/remote/firestore_mirror.dart';
import 'package:claimtrek/data/sync_service.dart';
import 'package:claimtrek/data/territory_repository.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory base;
  late RunPhotoStore store;

  Future<String> fakeShot([String content = 'jpeg']) async {
    final file = File(
      '${base.path}/camera_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsString(content);
    return file.path;
  }

  setUp(() async {
    base = await Directory.systemTemp.createTemp('claimtrek_photos');
    store = RunPhotoStore(baseDirectory: () async => base);
  });

  tearDown(() => base.delete(recursive: true));

  group('RunPhotoStore', () {
    test(
      'keeps the photo in the ClaimTrek folder and returns a relative path',
      () async {
        final path = await store.save(
          runId: 'r1',
          sourcePath: await fakeShot(),
        );

        expect(path, startsWith('ClaimTrek/run_r1_'));
        expect(path, endsWith('.jpg'));
        expect(Directory('${base.path}/ClaimTrek').existsSync(), isTrue);
        expect((await store.resolve(path))!.readAsStringSync(), 'jpeg');
      },
    );

    test('a retake replaces the previous photo of that run only', () async {
      final first = await store.save(
        runId: 'r1',
        sourcePath: await fakeShot('one'),
      );
      final other = await store.save(
        runId: 'r2',
        sourcePath: await fakeShot('two'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await store.save(
        runId: 'r1',
        sourcePath: await fakeShot('three'),
      );

      expect(await store.resolve(first), isNull);
      expect((await store.resolve(second))!.readAsStringSync(), 'three');
      expect(await store.resolve(other), isNotNull);
    });

    test('a missing or deleted photo resolves to nothing', () async {
      expect(await store.resolve(null), isNull);
      expect(await store.resolve('ClaimTrek/gone.jpg'), isNull);

      final path = await store.save(runId: 'r1', sourcePath: await fakeShot());
      await store.delete(path);
      expect(await store.resolve(path), isNull);
    });
  });

  group('RunPhotos', () {
    late ClaimTrekDatabase db;
    late TerritoryRepository repo;
    late FakeFirebaseFirestore firestore;
    late RunPhotos photos;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = ClaimTrekDatabase.forTesting(NativeDatabase.memory());
      final player = await PlayerIdentity.load();
      player.bindTo(uid: 'uid-a', displayName: 'Ana', photoUrl: null);
      repo = TerritoryRepository(db, player);
      firestore = FakeFirebaseFirestore();
      photos = RunPhotos(
        store,
        repo,
        SyncService(repo, FirestoreMirror(firestore), player),
      );
    });

    tearDown(() => db.close());

    Future<Run> aRun() => repo.saveRun(
      id: 'run-1',
      title: 'Morning run',
      isPublic: false,
      startedAt: 0,
      durationMs: 60000,
      distanceM: 500,
      steps: 0,
      elevationGainM: 0,
      areaM2: 0,
      verified: true,
      plausibleRatio: 1,
      reference: const LatLng(50.72, 10.45),
      track: const [LatLng(50.72, 10.45), LatLng(50.721, 10.45)],
    );

    test(
      'attaching stores the file locally and only its path in Firestore',
      () async {
        final updated = await photos.attach(await aRun(), await fakeShot());

        expect(updated!.photoPath, startsWith('ClaimTrek/'));
        expect((await db.runDao.byId('run-1'))!.photoPath, updated.photoPath);

        final doc = (await firestore.collection('runs').doc('run-1').get())
            .data()!;
        expect(doc['photoPath'], updated.photoPath);
        expect(
          doc.values.whereType<List<int>>(),
          isEmpty,
          reason: 'no image bytes',
        );
      },
    );

    test('removing deletes the file and clears the path everywhere', () async {
      final withPhoto = await photos.attach(await aRun(), await fakeShot());
      final cleared = await photos.remove(withPhoto!);

      expect(cleared!.photoPath, isNull);
      expect(await store.resolve(withPhoto.photoPath), isNull);
      final doc = (await firestore.collection('runs').doc('run-1').get())
          .data()!;
      expect(doc['photoPath'], isNull);
    });
  });
}
