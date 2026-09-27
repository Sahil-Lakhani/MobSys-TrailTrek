import 'package:flutter/foundation.dart';

import 'local/database.dart';
import 'player_identity.dart';
import 'remote/firestore_mirror.dart';
import 'territory_repository.dart';
import 'territory_sync.dart';

class SyncService {
  SyncService(
    this._repository,
    this._mirror,
    this._player, {
    this.territories,
    this.requestTimeout = const Duration(seconds: 20),
  });

  final TerritoryRepository _repository;
  final FirestoreMirror? _mirror;
  final PlayerIdentity _player;

  final TerritorySync? territories;

  final Duration requestTimeout;

  bool get enabled => _mirror != null && _player.isSignedIn;

  Future<void> onRunSaved(Run run) async {
    if (!enabled) return;
    await territories?.flush();
    await _bestEffort('mirror run', () async {
      await _mirror!.mirrorRun(
        runId: run.id,
        ownerId: _player.id,
        title: run.title,
        startedAt: run.startedAt,
        durationMs: run.durationMs,
        distanceM: run.distanceM,
        steps: run.steps,
        elevationGainM: run.elevationGainM,
        areaM2: run.areaM2,
        verified: run.verified,
        isPublic: run.isPublic,
        encodedPath: run.encodedPath,
        encodedElevation: run.encodedElevation,
      );
      await _publishStanding();
    });
  }

  Future<void> onSignedIn({required String previousOwnerId}) async {
    if (!enabled) return;
    await _bestEffort('adopt ground', () async {
      await _repository.adoptGroundFrom(previousOwnerId);
      await territories?.flush();
      await _publishStanding();
    });
  }

  Future<void> republishStanding() async {
    if (!enabled) return;
    await _bestEffort('restate standing', _publishStanding);
  }

  Future<void> _publishStanding() async {
    final standing = await _repository.currentStanding();
    await _mirror!.publishStanding(
      uid: _player.id,
      displayName: _player.name,
      colorHex: _player.colorHex,
      totalAreaM2: standing.totalAreaM2,
      territoryCount: standing.territoryCount,
    );
  }

  Future<void> _bestEffort(String what, Future<void> Function() body) async {
    try {
      await body().timeout(requestTimeout);
    } catch (error) {
      debugPrint('ClaimTrek: could not $what — $error');
    }
  }
}
