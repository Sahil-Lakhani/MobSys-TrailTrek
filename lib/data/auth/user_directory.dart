import 'package:cloud_firestore/cloud_firestore.dart';

class UserDirectory {
  UserDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  static const String collection = 'users';

  static const String privateCollection = 'private';
  static const String contactDocument = 'contact';

  static const String fallbackName = 'Runner';

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(collection);

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
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      if (colorHex != null && colorHex.isNotEmpty) 'colorHex': colorHex,
    };

    if (!existing.exists) data['createdAt'] = FieldValue.serverTimestamp();

    await document.set(data, SetOptions(merge: true));

    if (email != null && email.isNotEmpty) {
      await document
          .collection(privateCollection)
          .doc(contactDocument)
          .set({'email': email}, SetOptions(merge: true));
    }
  }

  Stream<Map<String, dynamic>?> watch(String uid) =>
      _users.doc(uid).snapshots().map((s) => s.data());
}
