import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Everything that follows a successful sign-in, whichever way the player signed in.
///
/// Files the profile, binds the account over the local identity, and hands the ground captured
/// before signing in to the account. Done here rather than waiting for the auth stream to reach
/// the identity provider, so that ground is adopted now and not on some later rebuild.
///
/// [handle] is the username typed when creating an email account; it becomes the `@username`
/// on the profile.
Future<void> completeSignIn(WidgetRef ref, User user, {String? handle}) async {
  final player = await ref.read(playerIdentityProvider.future);
  if (handle != null && player.handle == null) await player.setHandle(handle);

  await ref.read(userDirectoryProvider).upsertOnSignIn(
    uid: user.uid,
    displayName: user.displayName,
    email: user.email,
    photoUrl: user.photoURL,
    colorHex: player.colorHex,
  );

  final previousOwnerId = player.localId;
  player.bindTo(
    uid: user.uid,
    displayName: user.displayName,
    photoUrl: user.photoURL,
  );

  final sync = await ref.read(syncServiceProvider.future);
  await sync.onSignedIn(previousOwnerId: previousOwnerId);
}
