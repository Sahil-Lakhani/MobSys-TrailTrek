import 'package:claimtrek/data/player_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('signed out, you are an opaque local id', () async {
    final identity = await PlayerIdentity.load();

    expect(identity.isSignedIn, isFalse);
    expect(identity.id, isNotEmpty);
    expect(identity.id, identity.localId);
    expect(identity.name, PlayerIdentity.defaultName);
  });

  test('signing in makes the Firebase uid the identity', () async {
    final identity = await PlayerIdentity.load();
    final localId = identity.localId;

    identity.bindTo(uid: 'uid-a', displayName: 'Sahil', photoUrl: 'https://x/y.png');

    expect(identity.isSignedIn, isTrue);
    expect(identity.id, 'uid-a');
    expect(identity.name, 'Sahil');
    expect(identity.photoUrl, 'https://x/y.png');
    // The local id is kept, not overwritten: it is what the ground claimed before signing in
    // is still filed under, and re-owning it needs to know where to look.
    expect(identity.localId, localId);
  });

  test('a name you chose yourself wins over the Google one', () async {
    // Otherwise the name field on the profile screen silently does nothing while signed in,
    // which is worse than not offering it.
    final identity = await PlayerIdentity.load();
    identity.bindTo(uid: 'uid-a', displayName: 'Sahil Lakhani', photoUrl: null);

    await identity.setName('Trail runner');

    expect(identity.name, 'Trail runner');
  });

  test('clearing your chosen name hands the display back to Google', () async {
    final identity = await PlayerIdentity.load();
    identity.bindTo(uid: 'uid-a', displayName: 'Sahil Lakhani', photoUrl: null);
    await identity.setName('Trail runner');

    await identity.setName('');

    expect(identity.name, 'Sahil Lakhani');
  });

  test('a Google account with no name falls back rather than showing nothing', () async {
    final identity = await PlayerIdentity.load();
    await identity.setName('Trail runner');

    identity.bindTo(uid: 'uid-a', displayName: null, photoUrl: null);

    expect(identity.name, 'Trail runner');
  });

  test('signing out returns you to the local id', () async {
    final identity = await PlayerIdentity.load();
    final localId = identity.localId;

    identity.bindTo(uid: 'uid-a', displayName: 'Sahil', photoUrl: null);
    identity.unbind();

    expect(identity.isSignedIn, isFalse);
    expect(identity.id, localId);
    expect(identity.photoUrl, isNull);
  });

  test('the local id survives a restart', () async {
    final first = await PlayerIdentity.load();
    final id = first.localId;

    final second = await PlayerIdentity.load();

    expect(second.localId, id);
  });
}
