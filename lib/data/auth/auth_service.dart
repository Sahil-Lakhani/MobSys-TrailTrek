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
