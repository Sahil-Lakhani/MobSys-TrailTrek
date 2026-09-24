import 'package:cloud_firestore/cloud_firestore.dart';

/// The `users/{uid}` collection: one document per signed-in player.
///
/// Keyed by the Firebase uid rather than an auto-id, so a player has exactly one document no
/// matter how many times they sign in, and any other document can point at them by uid alone.
class UserDirectory {
  UserDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  static const String collection = 'users';

  /// Holds what only the account itself may read.
  ///
  /// The parent document is readable by every signed-in player, because the leaderboard needs
  /// their names, colours and totals. Rules do not cascade into a subcollection unless the
  /// match is recursive, so this one carries its own owner-only rule.
  static const String privateCollection = 'private';
  static const String contactDocument = 'contact';

  /// Shown when a Google account carries no name of its own. Nothing about a Google profile is
  /// guaranteed, and a null reaching the leaderboard would render as the word "null".
  static const String fallbackName = 'Runner';

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(collection);

  /// Creates the document on a first sign-in, and refreshes the profile on every one after.
  ///
  /// Merges rather than replaces: by the second sign-in this document also holds the player's
  /// standing, and a careless `set` would delete ground they had already earned.
  Future<void> upsertOnSignIn({
    required String uid,
    String? displayName,
    String? email,
    String? photoUrl,
    String? colorHex,
  }) async {
    final document = _users.doc(uid);
    final existing = await document.get();

    final data = <String, Object?>{
      'displayName': (displayName ?? '').trim().isEmpty
          ? fallbackName
          : displayName!.trim(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      // Null fields are left out entirely rather than written as null, so a profile that
      // gains a photo later is not competing with a stored blank.
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      if (colorHex != null && colorHex.isNotEmpty) 'colorHex': colorHex,
    };

    // Stamped once, on creation. Rewriting it every launch would make every account read as
    // brand new and quietly ruin any "playing since" ordering.
    if (!existing.exists) data['createdAt'] = FieldValue.serverTimestamp();

    await document.set(data, SetOptions(merge: true));

    // Deliberately not on the parent document: that one is world-readable to every signed-in
    // player, and an email address does not belong there.
    if (email != null && email.isNotEmpty) {
      await document
          .collection(privateCollection)
          .doc(contactDocument)
          .set({'email': email}, SetOptions(merge: true));
    }
  }

  /// The player's own document, as it changes.
  Stream<Map<String, dynamic>?> watch(String uid) =>
      _users.doc(uid).snapshots().map((s) => s.data());
}
