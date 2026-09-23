import 'package:flutter/foundation.dart';

import 'local/database.dart';
import 'player_identity.dart';
import 'remote/firestore_mirror.dart';
import 'territory_repository.dart';

/// Pushes what happened locally up to Firestore, once it has already happened locally.
///
/// Every method here runs *after* the local write has committed, and none of them can fail the
/// thing that triggered them. That ordering is the whole design: the game stays playable with
/// no account and no signal, and the cloud is a copy of the result rather than a step on the
/// way to it.
class SyncService {
  /// Positional for the same reason [TerritoryRepository] is: Dart forbids private *named*
  /// parameters, and these fields should stay private.
  SyncService(this._repository, this._mirror, this._player);

  final TerritoryRepository _repository;
  final FirestoreMirror? _mirror;
  final PlayerIdentity _player;

  /// Nothing is published for a player who has not signed in. They never agreed to put their
  /// GPS track anywhere, and there is no account to file it under.
  bool get enabled => _mirror != null && _player.isSignedIn;

  /// Mirrors a run that has already been saved locally, and republishes the standing it changed.
  Future<void> onRunSaved(Run run) async {
    if (!enabled) return;
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

  /// Takes ownership of ground captured before signing in, then publishes the result.
  Future<void> onSignedIn({required String previousOwnerId}) async {
    if (!enabled) return;
    await _bestEffort('adopt ground', () async {
      await _repository.adoptGroundFrom(previousOwnerId);
      await _publishStanding();
    });
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

  /// The local write has already committed by the time any of this runs. Letting a network
  /// error escape would surface to the runner as the save itself having failed, which it did
  /// not — so it is reported and dropped.
  Future<void> _bestEffort(String what, Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      debugPrint('ClaimTrek: could not $what — $error');
    }
  }
}
