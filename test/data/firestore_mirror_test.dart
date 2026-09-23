import 'package:claimtrek/data/remote/firestore_mirror.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreMirror mirror;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    mirror = FirestoreMirror(firestore);
  });

  Future<void> mirrorRun({
    String runId = 'run-1',
    String ownerId = 'uid-a',
    double areaM2 = 106200,
    bool verified = true,
  }) => mirror.mirrorRun(
    runId: runId,
    ownerId: ownerId,
    title: 'Afternoon run',
    startedAt: 1758620000000,
    durationMs: 41000,
    distanceM: 1253,
    steps: 812,
    elevationGainM: 167,
    areaM2: areaM2,
    verified: verified,
    isPublic: false,
    encodedPath: '50.7,10.4;50.8,10.5',
    encodedElevation: '0,111;600,278',
  );

  group('runs', () {
    test('a saved run is mirrored with its owner', () async {
      await mirrorRun();

      final doc = (await firestore.collection('runs').doc('run-1').get()).data();
      expect(doc, isNotNull);
      expect(doc!['ownerId'], 'uid-a');
      expect(doc['title'], 'Afternoon run');
      expect(doc['distanceM'], closeTo(1253, 1e-9));
      expect(doc['areaM2'], closeTo(106200, 1e-9));
      expect(doc['verified'], isTrue);
      expect(doc['encodedElevation'], '0,111;600,278');
      expect(doc['mirroredAt'], isNotNull);
    });

    test('mirroring the same run twice keeps one document', () async {
      // The local id is the document id, so a retry after a dropped connection must not create
      // a second copy of the same run.
      await mirrorRun();
      await mirrorRun();

      final all = await firestore.collection('runs').get();
      expect(all.docs, hasLength(1));
    });
  });

  group('standing', () {
    test('a standing is published for the leaderboard', () async {
      await mirror.publishStanding(
        uid: 'uid-a',
        displayName: 'Sahil',
        colorHex: '#FF6B35',
        totalAreaM2: 106200,
        territoryCount: 2,
      );

      final doc = (await firestore.collection('users').doc('uid-a').get()).data();
      expect(doc!['totalAreaM2'], closeTo(106200, 1e-9));
      expect(doc['territoryCount'], 2);
      expect(doc['displayName'], 'Sahil');
    });

    test('publishing a standing does not wipe the profile', () async {
      // UserDirectory writes the profile at sign-in; the standing arrives later, from a
      // different call site. A replacing write here would delete the email and photo.
      await firestore.collection('users').doc('uid-a').set({
        'displayName': 'Sahil',
        'email': 'sahil@example.com',
        'photoUrl': 'https://example.com/a.png',
      });

      await mirror.publishStanding(
        uid: 'uid-a',
        displayName: 'Sahil',
        colorHex: '#FF6B35',
        totalAreaM2: 106200,
        territoryCount: 2,
      );

      final doc = (await firestore.collection('users').doc('uid-a').get()).data();
      expect(doc!['email'], 'sahil@example.com');
      expect(doc['photoUrl'], 'https://example.com/a.png');
      expect(doc['totalAreaM2'], closeTo(106200, 1e-9));
    });
  });

  group('leaderboard', () {
    Future<void> seedUser(String uid, String name, double area) =>
        firestore.collection('users').doc(uid).set({
          'displayName': name,
          'colorHex': '#FF6B35',
          'totalAreaM2': area,
          'territoryCount': 1,
        });

    test('published standings become leaderboard rows', () async {
      await seedUser('uid-a', 'Sahil', 106200);
      await seedUser('uid-b', 'Ravi', 50000);

      final board = await mirror.watchLeaderboard(myId: 'uid-a').first;

      expect(board.map((e) => e.ownerName), containsAll(['Sahil', 'Ravi']));
      expect(board.firstWhere((e) => e.ownerId == 'uid-a').isYou, isTrue);
      expect(board.firstWhere((e) => e.ownerId == 'uid-b').isYou, isFalse);
    });

    test('an account that has never claimed is not a row', () async {
      // A user document is created at sign-in, before any ground exists.
      await firestore.collection('users').doc('uid-c').set({
        'displayName': 'New player',
      });

      final board = await mirror.watchLeaderboard(myId: 'uid-a').first;

      expect(board, isEmpty);
    });

    test('a malformed standing is skipped, not fatal', () async {
      // Any client can write its own user document; one bad row must not empty the board.
      await firestore.collection('users').doc('uid-bad').set({
        'displayName': 42,
        'totalAreaM2': 'lots',
      });
      await seedUser('uid-a', 'Sahil', 106200);

      final board = await mirror.watchLeaderboard(myId: 'uid-a').first;

      expect(board.map((e) => e.ownerName), ['Sahil']);
    });
  });
}
