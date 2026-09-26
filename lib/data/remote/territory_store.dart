import 'dart:math' as math;

import 'package:clipper2/clipper2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../geo/projection.dart';
import '../../geo/territory_engine.dart';
import '../local/database.dart';

/// A territory as another device published it.
///
/// Built only through [TerritoryStore.decode], which trusts nothing in the document: any client
/// can write to this collection, so types are checked, the geometry has to parse, and the area
/// is recomputed from the geometry rather than taken on the writer's word.
class RemoteTerritory {
  const RemoteTerritory({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.colorHex,
    required this.wkt,
    required this.areaM2,
    required this.verified,
    required this.geohash5,
    required this.refLat,
    required this.refLng,
    required this.claimedAt,
    required this.rev,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String colorHex;
  final String wkt;
  final double areaM2;
  final bool verified;
  final String geohash5;
  final double refLat;
  final double refLng;
  final int claimedAt;
  final int rev;

  /// Taken entirely, or folded into its owner's newer plot. Kept as a document so every device
  /// hears about the removal.
  bool get removed => wkt.isEmpty || areaM2 <= 0;

  /// As a local row that has nothing left to upload.
  Territory toRow() => Territory(
    id: id,
    ownerId: ownerId,
    ownerName: ownerName,
    colorHex: colorHex,
    wkt: wkt,
    areaM2: areaM2,
    geohash5: geohash5,
    refLat: refLat,
    refLng: refLng,
    claimedAt: claimedAt,
    verified: verified,
    rev: rev,
    dirty: false,
  );
}

/// One listener delivery: what changed, and — so ground deleted while this device was away
/// can be let go — every id the query currently holds.
class TerritorySnapshot {
  const TerritorySnapshot({
    required this.changed,
    required this.removedIds,
    required this.presentIds,
    required this.fromServer,
  });

  final List<RemoteTerritory> changed;

  /// Documents that left the query entirely.
  final List<String> removedIds;
  final Set<String> presentIds;

  /// False while the listener is still answering from the offline cache, which may be
  /// incomplete — nothing is concluded from an absence until the server has spoken.
  final bool fromServer;
}

/// What happened when a local change was published.
sealed class PublishResult {
  const PublishResult();
}

/// The server now holds [wkt] at [rev]; the local row should become exactly that.
///
/// The geometry may differ from what was sent: when another player took a bite in the
/// meantime, what lands is the ground both versions agree on.
class Published extends PublishResult {
  const Published({required this.rev, required this.wkt, required this.areaM2});

  final int rev;
  final String wkt;
  final double areaM2;
}

/// The territory no longer exists anywhere; the local row should go.
class Gone extends PublishResult {
  const Gone();
}

/// Reads and writes `territories/{id}` in Firestore.
///
/// Territory only shrinks once it exists. Its owner creates it; after that, anyone may take
/// ground from it but nobody may add ground to it in place — a runner's growing holding is a
/// new document, and the plots it absorbed become removals. That one rule is what makes
/// concurrent steals safe: two devices that each took a different bite merge by keeping only
/// what both still hold, and every device lands on the same shape in any order.
class TerritoryStore {
  TerritoryStore(this._firestore);

  final FirebaseFirestore _firestore;

  static const String collection = 'territories';

  /// Longest WKT accepted from the network. A run is a few thousand points at most; anything
  /// far beyond that is someone trying to make every device parse a megabyte.
  static const int maxWktLength = 200000;

  CollectionReference<Map<String, dynamic>> get _territories =>
      _firestore.collection(collection);

  /// Territory touching any of [cells], as it changes.
  Stream<TerritorySnapshot> watchCells(List<String> cells) => _territories
      .where('cells', arrayContainsAny: cells)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        final changed = <RemoteTerritory>[];
        final removed = <String>[];
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.removed) {
            removed.add(change.doc.id);
            continue;
          }
          final data = change.doc.data();
          final decoded = data == null ? null : decode(change.doc.id, data);
          if (decoded != null) changed.add(decoded);
        }
        return TerritorySnapshot(
          changed: changed,
          removedIds: removed,
          presentIds: {for (final d in snapshot.docs) d.id},
          fromServer: !snapshot.metadata.isFromCache,
        );
      });

  /// Publishes one local change, reconciling it with whatever the server holds.
  ///
  /// Runs as a transaction, so a steal that lands on the server between reading and writing
  /// is merged rather than overwritten.
  Future<PublishResult> publish(Territory local, {required bool isOwner}) {
    final doc = _territories.doc(local.id);

    return _firestore.runTransaction<PublishResult>((tx) async {
      final snapshot = await tx.get(doc);
      final data = snapshot.data();
      final remote = data == null ? null : decode(snapshot.id, data);

      final localGeometry = local.areaM2 <= 0
          ? null
          : TerritoryEngine.fromWkt(local.wkt);

      // Never published. Only the owner may put ground on the map; a removal of something
      // that was never there has nothing to remove.
      if (!snapshot.exists) {
        if (!isOwner || localGeometry == null || localGeometry.isEmpty) {
          return const Gone();
        }
        tx.set(doc, _encode(local, localGeometry));
        return Published(rev: local.rev, wkt: local.wkt, areaM2: local.areaM2);
      }

      // Already removed on the server — or unreadable, which is treated the same way, since a
      // corrupt document is no ground to anyone. A removal is final: nothing revives it.
      if (remote == null || remote.removed) return const Gone();

      final theirs = TerritoryEngine.fromWkt(remote.wkt)!;
      final merged = localGeometry == null
          ? <PathD>[]
          : TerritoryEngine.intersect(theirs, localGeometry);
      final area = merged.isEmpty ? 0.0 : TerritoryEngine.areaM2(merged);
      final rev = math.max(remote.rev, local.rev) + 1;

      if (merged.isEmpty || area < TerritoryEngine.sliverAreaM2) {
        tx.update(doc, {
          'wkt': '',
          'areaM2': 0,
          'rev': rev,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return Published(rev: rev, wkt: '', areaM2: 0);
      }

      final wkt = TerritoryEngine.toWkt(merged);

      if (isOwner) {
        // The owner restates everything about the plot — including a new name or colour —
        // but the ground itself is still only what both copies hold.
        tx.update(doc, {
          'ownerName': local.ownerName,
          'colorHex': local.colorHex,
          'verified': local.verified,
          'wkt': wkt,
          'areaM2': area,
          'rev': rev,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return Published(rev: rev, wkt: wkt, areaM2: area);
      }

      // Someone else's plot. If our copy takes nothing the server's does not already lack, the
      // server's version is simply the newer truth.
      if (area >= remote.areaM2 - 1.0) {
        return Published(
          rev: remote.rev,
          wkt: remote.wkt,
          areaM2: remote.areaM2,
        );
      }

      // Only the ground fields: the security rules refuse anything else from a non-owner.
      tx.update(doc, {
        'wkt': wkt,
        'areaM2': area,
        'rev': rev,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return Published(rev: rev, wkt: wkt, areaM2: area);
    });
  }

  Map<String, dynamic> _encode(Territory row, PathsD geometry) {
    final bounds = TerritoryEngine.boundsOf(geometry)!;
    return {
      'ownerId': row.ownerId,
      'ownerName': row.ownerName,
      'colorHex': row.colorHex,
      'wkt': row.wkt,
      'areaM2': row.areaM2,
      'verified': row.verified,
      'geohash5': row.geohash5,
      'cells': Projection.cellsCovering(
        minLat: bounds.minLat,
        maxLat: bounds.maxLat,
        minLng: bounds.minLng,
        maxLng: bounds.maxLng,
      ),
      'refLat': row.refLat,
      'refLng': row.refLng,
      'claimedAt': row.claimedAt,
      'rev': row.rev,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static final RegExp _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// A document as a [RemoteTerritory], or null when it cannot be trusted enough to draw.
  static RemoteTerritory? decode(String id, Map<String, dynamic> data) {
    final ownerId = data['ownerId'];
    if (ownerId is! String || ownerId.isEmpty) return null;

    final wkt = data['wkt'];
    if (wkt is! String || wkt.length > maxWktLength) return null;

    final rawRev = data['rev'];
    final rev = rawRev is num ? rawRev.toInt() : 0;

    final name = data['ownerName'];
    final colour = data['colorHex'];
    final claimedAt = data['claimedAt'];

    PathsD? geometry;
    if (wkt.isNotEmpty) {
      geometry = TerritoryEngine.fromWkt(wkt);
      // Ground that will not parse cannot be drawn, clipped or scored. Skipped rather than
      // treated as a removal, so a garbled write cannot erase a rival's plot on every device.
      if (geometry == null || geometry.isEmpty) return null;
    }

    final area = geometry == null ? 0.0 : TerritoryEngine.areaM2(geometry);
    final centre = geometry == null
        ? null
        : TerritoryEngine.referenceOf(geometry);

    return RemoteTerritory(
      id: id,
      ownerId: ownerId,
      ownerName: name is String && name.trim().isNotEmpty
          ? (name.length > 60 ? name.substring(0, 60) : name)
          : 'Runner',
      colorHex: colour is String && _hex.hasMatch(colour) ? colour : '#FF6B35',
      wkt: area > 0 ? wkt : '',
      areaM2: area,
      verified: data['verified'] == true,
      geohash5: centre == null
          ? (data['geohash5'] is String ? data['geohash5'] as String : '')
          : Projection.geohash5(centre),
      refLat: centre?.latitude ?? _num(data['refLat']),
      refLng: centre?.longitude ?? _num(data['refLng']),
      claimedAt: claimedAt is num
          ? claimedAt.toInt()
          : DateTime.now().millisecondsSinceEpoch,
      rev: rev,
    );
  }

  static double _num(Object? v) => v is num ? v.toDouble() : 0.0;
}
