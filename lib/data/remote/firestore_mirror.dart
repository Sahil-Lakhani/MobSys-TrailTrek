import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/models.dart';

/// Publishes what this device has done to Firestore, and reads back what everyone else has.
///
/// A mirror, not the source of truth. The local database still owns the game: claims are
/// computed, resolved and committed locally, and only then copied here. That is what keeps the
/// app playable on a train with no signal, and it means a failed write costs a leaderboard
/// update rather than a run.
class FirestoreMirror {
  FirestoreMirror(this._firestore);

  final FirebaseFirestore _firestore;

  static const String runsCollection = 'runs';
  static const String usersCollection = 'users';

  /// Copies one saved run up.
  ///
  /// The local run id is the document id, so a retry after a dropped connection overwrites its
  /// own earlier attempt instead of leaving a duplicate behind.
  Future<void> mirrorRun({
    required String runId,
    required String ownerId,
    required String title,
    required int startedAt,
    required int durationMs,
    required double distanceM,
    required int steps,
    required double elevationGainM,
    required double areaM2,
    required bool verified,
    required bool isPublic,
    required String encodedPath,
    required String encodedElevation,
  }) => _firestore.collection(runsCollection).doc(runId).set({
    'ownerId': ownerId,
    'title': title,
    'startedAt': startedAt,
    'durationMs': durationMs,
    'distanceM': distanceM,
    'steps': steps,
    'elevationGainM': elevationGainM,
    'areaM2': areaM2,
    'verified': verified,
    'isPublic': isPublic,
    'encodedPath': encodedPath,
    'encodedElevation': encodedElevation,
    'mirroredAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  /// Publishes the player's total holding, which is what the leaderboard ranks on.
  ///
  /// Merged rather than replaced: this document is also the player's profile, written at
  /// sign-in by a different call site, and a replacing write would delete their email and photo.
  Future<void> publishStanding({
    required String uid,
    required String displayName,
    required String colorHex,
    required double totalAreaM2,
    required int territoryCount,
  }) => _firestore.collection(usersCollection).doc(uid).set({
    'displayName': displayName,
    'colorHex': colorHex,
    'totalAreaM2': totalAreaM2,
    'territoryCount': territoryCount,
    'standingUpdatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  /// Every player who holds ground, as it changes.
  ///
  /// Ranks are left at zero here: the rows are merged with the local board before anyone is
  /// numbered, and numbering twice would be numbering the wrong list.
  Stream<List<LeaderboardEntry>> watchLeaderboard({required String myId}) =>
      _firestore
          .collection(usersCollection)
          .snapshots()
          .map((snapshot) => _toEntries(snapshot.docs, myId));

  List<LeaderboardEntry> _toEntries(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String myId,
  ) {
    final out = <LeaderboardEntry>[];
    for (final doc in docs) {
      final data = doc.data();

      // Any client can write its own user document, so nothing here is trusted to have the
      // type it should. One malformed row costs its own line, never the whole board.
      final area = data['totalAreaM2'];
      if (area is! num || area <= 0) continue;

      final name = data['displayName'];
      if (name is! String || name.isEmpty) continue;

      final colour = data['colorHex'];
      final count = data['territoryCount'];

      out.add(
        LeaderboardEntry(
          rank: 0,
          ownerId: doc.id,
          ownerName: name,
          colorHex: colour is String && colour.isNotEmpty ? colour : '#FF6B35',
          totalAreaM2: area.toDouble(),
          territoryCount: count is num ? count.toInt() : 1,
          isYou: doc.id == myId,
        ),
      );
    }
    return out;
  }
}
