import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Sign-in, kept thin on purpose.
///
/// Everything with rules in it — what a user document holds, what survives a second sign-in —
/// lives in [UserDirectory], where it can be tested against a fake. What is left here is the
/// platform handshake, which only a real device can exercise.
class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  bool _initialized = false;

  /// Null while signed out. Emits on every sign-in and sign-out, which is what the router
  /// listens to rather than the app checking once at launch.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// google_sign_in 7 requires an explicit one-time init before any attempt.
  ///
  /// The Android client id is read from `google-services.json`, so nothing is passed here —
  /// hardcoding it would mean a second place to update when the Firebase project changes.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _google.initialize();
    _initialized = true;
  }

  /// Returns null when the user backed out, which is a normal outcome and not an error.
  ///
  /// Throws [FirebaseAuthException] for a genuine failure, so the caller can say something
  /// truthful rather than showing a spinner that never stops.
  Future<User?> signInWithGoogle() async {
    // On web the redirect/popup is Firebase's own: google_sign_in's authenticate() is not
    // supported there, and calling it throws rather than falling back.
    if (kIsWeb) {
      final credential = await _auth.signInWithPopup(GoogleAuthProvider());
      return credential.user;
    }

    await _ensureInitialized();

    if (!_google.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google sign-in is not available on this platform.',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      // Almost always a misconfigured SHA-1 or a missing web client id rather than anything
      // the user did — say so, because "sign-in failed" sends people hunting in the wrong place.
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message:
            'Google returned no ID token. Check that this build\'s SHA-1 is registered '
            'on the Firebase Android app and that google-services.json is current.',
      );
    }

    final credential = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    return credential.user;
  }

  /// Creates an email-and-password account, with [username] as its display name.
  ///
  /// Throws [FirebaseAuthException]; [describeAuthError] turns one into something to show.
  Future<User?> signUpWithEmail({
    required String username,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) return null;

    await user.updateDisplayName(username.trim());
    // The name is written to the server; the local User object only learns it on a reload,
    // and the caller files the leaderboard name from this object.
    await user.reload();
    return _auth.currentUser;
  }

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// How the current account signs in, for the profile to show: "Google" or "Email".
  String? get providerLabel {
    final providers = _auth.currentUser?.providerData.map((p) => p.providerId);
    if (providers == null) return null;
    if (providers.contains('google.com')) return 'Google';
    if (providers.contains('password')) return 'Email';
    return null;
  }

  Future<void> signOut() async {
    // Firebase first: if the Google half fails, the app is still signed out rather than
    // stranded in a state where the UI says signed-in but the token is gone.
    await _auth.signOut();
    if (!kIsWeb) {
      await _ensureInitialized();
      await _google.signOut();
    }
  }
}

/// A sign-in failure, in words a runner can act on.
///
/// Firebase's own messages are written for developers ("The supplied auth credential is
/// incorrect, malformed or has expired"), and the raw exception text is worse.
String describeAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'email-already-in-use':
        return 'An account with that email already exists. Sign in instead.';
      case 'weak-password':
        return 'Choose a password of at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not switched on for the app yet '
            '(Firebase console → Authentication → Sign-in method).';
      case 'missing-id-token':
        return error.message ?? 'Google sign-in is not set up for this build.';
    }
    return error.message ?? 'Sign-in failed (${error.code}).';
  }
  if (error is GoogleSignInException) {
    return 'Google sign-in failed (${error.code.name}). On a new computer this usually means '
        'its SHA-1 fingerprint is not registered in the Firebase project.';
  }
  return 'Sign-in failed: $error';
}
