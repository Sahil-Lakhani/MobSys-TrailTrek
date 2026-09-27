import 'dart:async';

import 'package:clipper2/clipper2.dart';
import 'package:flutter/foundation.dart';

import '../geo/lat_lng.dart';
import '../geo/projection.dart';
import '../geo/territory_engine.dart';
import 'local/database.dart';
import 'player_identity.dart';
import 'remote/territory_store.dart';
import 'territory_repository.dart';

/// Keeps this device's territory and everyone else's in step.
///
/// Two directions, both built so the game never waits on the network:
///
/// * **Up.** Claims are resolved against the local database and flagged `dirty`. [flush]
///   publishes every flagged row and clears the flag only once the server has it, so a claim
///   made with no signal is still published when the signal returns — by the next flush, which
///   runs after every save, on sign-in, and on a timer.
/// * **Down.** [follow] listens to the territory around the runner and folds each change into
///   the local database, where the map and the claim engine already read from.
///
/// Both merge by the same rule: territory only shrinks once it exists, so two versions of one
/// plot combine by keeping what both still hold. That rule is what lets two phones steal from
/// the same rival at the same moment and still agree afterwards.
class TerritorySync {
  /// Positional for the same reason as [TerritoryRepository]: Dart forbids private *named*
  /// parameters.
  TerritorySync(
    this._db,
    this._store,
    this._player, {
    this.onOwnGroundChanged,
    this.flushInterval = const Duration(seconds: 45),
    this.requestTimeout = const Duration(seconds: 20),
  });

  final ClaimTrekDatabase _db;
  final TerritoryStore? _store;
  final PlayerIdentity _player;

  /// Called when this player's own holding changed from outside — someone took ground from
  /// them — so the published standing can be restated.
  final Future<void> Function()? onOwnGroundChanged;

  final Duration flushInterval;
  final Duration requestTimeout;

  TerritoryDao get _territories => _db.territoryDao;

  /// Only a signed-in player shares ground. Without an account there is nobody to publish it
  /// as, and nobody has agreed to their runs leaving the phone.
  bool get enabled => _store != null && _player.isSignedIn;

  Timer? _timer;
  StreamSubscription<TerritorySnapshot>? _subscription;
  String? _cellsKey;
  List<String> _cells = const [];
  bool _reconciled = false;
  bool _disposed = false;

  /// Snapshot handling runs one delivery at a time, in order.
  Future<void> _applying = Future.value();

  Future<void>? _flushing;
  bool _flushAgain = false;

  /// Starts the retry timer. Safe to call more than once.
  ///
  /// Only when there is somewhere to publish to: a local-only build has nothing to retry.
  void start() {
    if (_disposed || _timer != null || _store == null) return;
    _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  // ---------------------------------------------------------------------------- up

  /// Publishes everything waiting to go up. Never throws.
  ///
  /// Calls that arrive while one is running fold into a single follow-up pass, so a burst of
  /// triggers costs at most two passes and no row is uploaded twice at once.
  Future<void> flush() {
    final running = _flushing;
    if (running != null) {
      _flushAgain = true;
      return running;
    }
    final pass = _flushLoop();
    _flushing = pass;
    return pass.whenComplete(() => _flushing = null);
  }

  Future<void> _flushLoop() async {
    do {
      _flushAgain = false;
      try {
        await _flushOnce();
      } catch (error, stack) {
        debugPrint('ClaimTrek: territory upload failed — $error\n$stack');
      }
    } while (_flushAgain && !_disposed);
  }

  Future<void> _flushOnce() async {
    await _restampOwnGround();

    var ownChanged = false;
    for (final row in await _territories.getDirty()) {
      if (_disposed) return;

      // Stand-in rivals are local props. Their changes are final the moment they are made.
      if (TerritoryRepository.isLocalOnly(row)) {
        if (row.areaM2 <= 0) {
          await _territories.deleteIfRev(row.id, row.rev);
        } else {
          await _territories.markPublished(
            row.id,
            expectedRev: row.rev,
            newRev: row.rev,
          );
        }
        continue;
      }

      // Left flagged: it goes up once there is an account to publish it under.
      if (!enabled) return;

      final isOwner = row.ownerId == _player.id;
      final PublishResult result;
      try {
        result = await _store!
            .publish(row, isOwner: isOwner)
            .timeout(requestTimeout);
      } catch (error) {
        // Offline, timed out, or refused. The flag stays, and the next flush tries again.
        debugPrint('ClaimTrek: could not publish territory ${row.id} — $error');
        continue;
      }

      switch (result) {
        case Gone():
          await _territories.deleteIfRev(row.id, row.rev);
          if (isOwner && row.areaM2 > 0) ownChanged = true;
        case Published(:final rev, :final wkt, :final areaM2):
          if (areaM2 <= 0) {
            await _territories.deleteIfRev(row.id, row.rev);
          } else {
            await _territories.markPublished(
              row.id,
              expectedRev: row.rev,
              newRev: rev,
              wkt: wkt,
              areaM2: areaM2,
            );
          }
          // The server merged in a steal this device had not heard about yet.
          if (isOwner && (areaM2 - row.areaM2).abs() > 1.0) ownChanged = true;
      }
    }

    // Not awaited: restating the standing is a network write, and this pass holds the upload
    // lock — waiting on it with no signal would stall every upload after this one.
    if (ownChanged) unawaited(_notifyOwnGroundChanged());
  }

  /// A new name or colour reaches ground claimed under the old one.
  ///
  /// Territory is stamped with its owner's name and colour when claimed, because rivals draw it
  /// without looking anything up. Changing either on the profile would otherwise leave every
  /// existing plot showing the old ones.
  Future<void> _restampOwnGround() async {
    if (!enabled) return;
    final mine = await _territories.getByOwner(_player.id);
    final stale = [
      for (final t in mine)
        if (t.ownerName != _player.name || t.colorHex != _player.colorHex)
          t.copyWith(
            ownerName: _player.name,
            colorHex: _player.colorHex,
            rev: t.rev + 1,
            dirty: true,
          ),
    ];
    if (stale.isNotEmpty) await _territories.upsertAll(stale);
  }

  // -------------------------------------------------------------------------- down

  /// Listens to the territory around [where], moving the listener when the runner leaves the
  /// area it covers. Cheap to call on every fix: it does nothing until the cell changes.
  void follow(LatLng where) {
    if (!enabled || _disposed) return;
    final cells = Projection.neighbourhood5(where)..sort();
    final key = cells.join(',');
    if (key == _cellsKey) return;

    _cellsKey = key;
    _cells = cells;
    _reconciled = false;
    unawaited(_subscription?.cancel());
    _subscription = _store!
        .watchCells(cells)
        .listen(
          (snapshot) {
            _applying = _applying.then((_) => _apply(snapshot)).catchError((
              Object error,
              StackTrace stack,
            ) {
              debugPrint(
                'ClaimTrek: could not apply territory update — $error\n$stack',
              );
            });
          },
          onError: (Object error) {
            debugPrint('ClaimTrek: territory listener failed — $error');
            // Forget the area so the next fix opens a fresh listener rather than trusting a
            // dead one.
            _cellsKey = null;
          },
        );
  }

  /// Folds one listener delivery into the local database.
  @visibleForTesting
  Future<void> applySnapshot(TerritorySnapshot snapshot) => _apply(snapshot);

  Future<void> _apply(TerritorySnapshot snapshot) async {
    if (_disposed) return;
    var ownChanged = false;
    var requeued = false;

    await _db.transaction(() async {
      for (final remote in snapshot.changed) {
        if (await _merge(remote)) ownChanged = true;
      }

      for (final id in snapshot.removedIds) {
        final local = await _territories.byId(id);
        if (local == null || local.dirty) continue;
        await _territories.deleteByIds([id]);
        if (local.ownerId == _player.id) ownChanged = true;
      }

      // The first complete answer from the server is the one moment an absence means something:
      // ground this device still shows that no longer exists anywhere.
      if (snapshot.fromServer && !_reconciled) {
        _reconciled = true;
        requeued = await _reconcile(snapshot.presentIds);
      }
    });

    if (requeued) unawaited(flush());
    if (ownChanged) await _notifyOwnGroundChanged();
  }

  /// Applies one remote version of a territory. Returns whether this player's own ground moved.
  Future<bool> _merge(RemoteTerritory remote) async {
    final local = await _territories.byId(remote.id);
    final isOwn = remote.ownerId == _player.id;

    // A removal is final, whatever this device thought of the plot.
    if (remote.removed) {
      if (local == null) return false;
      await _territories.deleteByIds([remote.id]);
      return isOwn && local.areaM2 > 0;
    }

    if (local == null) {
      await _territories.upsert(remote.toRow());
      return isOwn;
    }

    // Removed here and not yet published: the removal is the newer fact.
    if (local.areaM2 <= 0) return false;

    if (!local.dirty) {
      if (remote.rev < local.rev) return false;
      if (remote.rev == local.rev && remote.wkt == local.wkt) return false;
      await _territories.upsert(remote.toRow());
      return isOwn && (remote.areaM2 - local.areaM2).abs() > 1.0;
    }

    // The echo of this device's own upload.
    if (remote.rev == local.rev && remote.wkt == local.wkt) {
      await _territories.markPublished(
        local.id,
        expectedRev: local.rev,
        newRev: local.rev,
      );
      return false;
    }

    // An older version than the one waiting to go up: the upload will reconcile with it.
    if (remote.rev < local.rev) return false;

    // Both sides changed. Keep what both still hold, and leave it flagged so the merge is
    // published too.
    final merged = TerritoryEngine.intersect(
      TerritoryEngine.fromWkt(remote.wkt)!,
      TerritoryEngine.fromWkt(local.wkt) ?? const <PathD>[],
    );
    final area = merged.isEmpty ? 0.0 : TerritoryEngine.areaM2(merged);
    final next = remote.rev > local.rev ? remote.rev + 1 : local.rev + 1;

    if (merged.isEmpty || area < TerritoryEngine.sliverAreaM2) {
      await _territories.upsert(
        TerritoryRepository.tombstone(local).copyWith(rev: next),
      );
    } else {
      await _territories.upsert(
        local.copyWith(
          // The owner decides how their plot is labelled; only this player's own name is
          // taken from here.
          ownerName: isOwn ? local.ownerName : remote.ownerName,
          colorHex: isOwn ? local.colorHex : remote.colorHex,
          verified: isOwn ? local.verified : remote.verified,
          wkt: TerritoryEngine.toWkt(merged),
          areaM2: area,
          rev: next,
          dirty: true,
        ),
      );
    }
    return isOwn && (area - local.areaM2).abs() > 1.0;
  }

  /// Lets go of ground that no longer exists on the server. Returns whether any of this
  /// player's own ground was queued to go back up.
  Future<bool> _reconcile(Set<String> presentIds) async {
    final nearby = await _territories.getInCells(_cells);
    var requeued = false;
    for (final row in nearby) {
      if (presentIds.contains(row.id)) continue;
      if (TerritoryRepository.isLocalOnly(row) || row.dirty) continue;

      if (row.ownerId == _player.id) {
        // This player's ground, missing from the server — never uploaded, or lost there. It is
        // theirs and it is here, so it goes back up rather than being thrown away.
        await _territories.upsert(row.copyWith(rev: row.rev + 1, dirty: true));
        requeued = true;
      } else {
        await _territories.deleteByIds([row.id]);
      }
    }
    return requeued;
  }

  Future<void> _notifyOwnGroundChanged() async {
    final callback = onOwnGroundChanged;
    if (callback == null) return;
    try {
      await callback();
    } catch (error) {
      debugPrint('ClaimTrek: could not restate standing — $error');
    }
  }
}
