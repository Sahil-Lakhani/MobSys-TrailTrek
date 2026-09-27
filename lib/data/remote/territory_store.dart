import 'dart:math' as math;

import 'package:clipper2/clipper2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../geo/projection.dart';
import '../../geo/territory_engine.dart';
import '../local/database.dart';

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

  bool get removed => wkt.isEmpty || areaM2 <= 0;

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

class TerritorySnapshot {
  const TerritorySnapshot({
    required this.changed,
    required this.removedIds,
    required this.presentIds,
    required this.fromServer,
  });

  final List<RemoteTerritory> changed;

  final List<String> removedIds;
  final Set<String> presentIds;

  final bool fromServer;
}

sealed class PublishResult {
  const PublishResult();
}

class Published extends PublishResult {
  const Published({required this.rev, required this.wkt, required this.areaM2});

  final int rev;
  final String wkt;
  final double areaM2;
}

class Gone extends PublishResult {
  const Gone();
}

class TerritoryStore {
  TerritoryStore(this._firestore);

  final FirebaseFirestore _firestore;

  static const String collection = 'territories';

  static const int maxWktLength = 200000;

  CollectionReference<Map<String, dynamic>> get _territories =>
      _firestore.collection(collection);

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

  Future<PublishResult> publish(Territory local, {required bool isOwner}) {
    final doc = _territories.doc(local.id);

    return _firestore.runTransaction<PublishResult>((tx) async {
      final snapshot = await tx.get(doc);
      final data = snapshot.data();
      final remote = data == null ? null : decode(snapshot.id, data);

      final localGeometry = local.areaM2 <= 0
          ? null
          : TerritoryEngine.fromWkt(local.wkt);

      if (!snapshot.exists) {
        if (!isOwner || localGeometry == null || localGeometry.isEmpty) {
          return const Gone();
        }
        tx.set(doc, _encode(local, localGeometry));
        return Published(rev: local.rev, wkt: local.wkt, areaM2: local.areaM2);
      }

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

      if (area >= remote.areaM2 - 1.0) {
        return Published(
          rev: remote.rev,
          wkt: remote.wkt,
          areaM2: remote.areaM2,
        );
      }

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
