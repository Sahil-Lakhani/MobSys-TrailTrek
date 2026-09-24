import 'package:claimtrek/data/auth/user_directory.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late UserDirectory directory;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    directory = UserDirectory(firestore);
  });

  Future<Map<String, dynamic>?> read(String uid) async =>
      (await firestore.collection('users').doc(uid).get()).data();

  test('a first sign-in creates the user document', () async {
    await directory.upsertOnSignIn(
      uid: 'uid-1',
      displayName: 'Sahil Lakhani',
      email: 'sahil@example.com',
      photoUrl: 'https://example.com/a.png',
      colorHex: '#FF6B35',
    );

    final doc = await read('uid-1');
    expect(doc, isNotNull);
    expect(doc!['displayName'], 'Sahil Lakhani');
    expect(doc['photoUrl'], 'https://example.com/a.png');
    expect(doc['colorHex'], '#FF6B35');
    expect(doc['createdAt'], isNotNull);
    expect(doc['lastSeenAt'], isNotNull);
  });

  test('the email is not in the document every player can read', () async {
    // The leaderboard needs names, colours and totals from every player, so this document is
    // readable by anyone signed in. An email address has no business being reachable that way,
    // and the repository holding this project is public.
    await directory.upsertOnSignIn(
      uid: 'uid-1',
      displayName: 'Sahil Lakhani',
      email: 'sahil@example.com',
    );

    final doc = await read('uid-1');
    expect(doc!.containsKey('email'), isFalse);
  });

  test('the email is kept where only its owner can reach it', () async {
    await directory.upsertOnSignIn(
      uid: 'uid-1',
      displayName: 'Sahil Lakhani',
      email: 'sahil@example.com',
    );

    final private = await firestore
        .collection('users')
        .doc('uid-1')
        .collection(UserDirectory.privateCollection)
        .doc(UserDirectory.contactDocument)
        .get();

    expect(private.data()?['email'], 'sahil@example.com');
  });

  test('the document id is the uid, so a player has exactly one', () async {
    await directory.upsertOnSignIn(uid: 'uid-1', displayName: 'A');
    await directory.upsertOnSignIn(uid: 'uid-1', displayName: 'A');

    final all = await firestore.collection('users').get();
    expect(all.docs, hasLength(1));
    expect(all.docs.single.id, 'uid-1');
  });

  test('signing in again refreshes the profile without wiping the rest', () async {
    await directory.upsertOnSignIn(uid: 'uid-1', displayName: 'Old Name');
    // Something the app wrote later that a careless overwrite would destroy.
    await firestore.collection('users').doc('uid-1').set({
      'totalAreaM2': 10640.5,
    }, SetOptions(merge: true));

    await directory.upsertOnSignIn(uid: 'uid-1', displayName: 'New Name');

    final doc = await read('uid-1');
    expect(doc!['displayName'], 'New Name');
    expect(
      doc['totalAreaM2'],
      closeTo(10640.5, 1e-9),
      reason: 'a merge, not a replace — held ground must survive a sign-in',
    );
  });

  test('createdAt is stamped once and never moved', () async {
    await directory.upsertOnSignIn(uid: 'uid-1', displayName: 'A');
    final first = (await read('uid-1'))!['createdAt'];

    await directory.upsertOnSignIn(uid: 'uid-1', displayName: 'A');
    final second = (await read('uid-1'))!['createdAt'];

    // Rewriting this on every launch would make every account look brand new.
    expect(second, first);
  });

  test('a Google account with no display name still gets a document', () async {
    // Nothing about a Google profile is guaranteed — an account can have no name and no photo,
    // and a null here must not become the literal string "null" on the leaderboard.
    await directory.upsertOnSignIn(uid: 'uid-2', displayName: null, email: null);

    final doc = await read('uid-2');
    expect(doc, isNotNull);
    expect(doc!['displayName'], UserDirectory.fallbackName);
    expect(doc.containsKey('email'), isFalse, reason: 'absent, not "null"');
  });
}
