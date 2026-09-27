import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/models.dart';

class FirestoreMirror {
  FirestoreMirror(this._firestore);

  final FirebaseFirestore _firestore;

  static const String runsCollection = 'runs';
  static const String usersCollection = 'users';

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
