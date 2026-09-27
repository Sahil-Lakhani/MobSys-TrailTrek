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

class TerritorySync {
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

  final Future<void> Function()? onOwnGroundChanged;

  final Duration flushInterval;
  final Duration requestTimeout;

  TerritoryDao get _territories => _db.territoryDao;

  bool get enabled => _store != null && _player.isSignedIn;

  Timer? _timer;
  StreamSubscription<TerritorySnapshot>? _subscription;
  String? _cellsKey;
  List<String> _cells = const [];
  bool _reconciled = false;
  bool _disposed = false;

  Future<void> _applying = Future.value();

  Future<void>? _flushing;
  bool _flushAgain = false;

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

      if (!enabled) return;

      final isOwner = row.ownerId == _player.id;
      final PublishResult result;
      try {
        result = await _store!
            .publish(row, isOwner: isOwner)
            .timeout(requestTimeout);
      } catch (error) {
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
          if (isOwner && (areaM2 - row.areaM2).abs() > 1.0) ownChanged = true;
      }
    }

    if (ownChanged) unawaited(_notifyOwnGroundChanged());
  }

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
            _cellsKey = null;
          },
        );
  }

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

      if (snapshot.fromServer && !_reconciled) {
        _reconciled = true;
        requeued = await _reconcile(snapshot.presentIds);
      }
    });

    if (requeued) unawaited(flush());
    if (ownChanged) await _notifyOwnGroundChanged();
  }

  Future<bool> _merge(RemoteTerritory remote) async {
    final local = await _territories.byId(remote.id);
    final isOwn = remote.ownerId == _player.id;

    if (remote.removed) {
      if (local == null) return false;
      await _territories.deleteByIds([remote.id]);
      return isOwn && local.areaM2 > 0;
    }

    if (local == null) {
      await _territories.upsert(remote.toRow());
      return isOwn;
    }

    if (local.areaM2 <= 0) return false;

    if (!local.dirty) {
      if (remote.rev < local.rev) return false;
      if (remote.rev == local.rev && remote.wkt == local.wkt) return false;
      await _territories.upsert(remote.toRow());
      return isOwn && (remote.areaM2 - local.areaM2).abs() > 1.0;
    }

    if (remote.rev == local.rev && remote.wkt == local.wkt) {
      await _territories.markPublished(
        local.id,
        expectedRev: local.rev,
        newRev: local.rev,
      );
      return false;
    }

    if (remote.rev < local.rev) return false;

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

  Future<bool> _reconcile(Set<String> presentIds) async {
    final nearby = await _territories.getInCells(_cells);
    var requeued = false;
    for (final row in nearby) {
      if (presentIds.contains(row.id)) continue;
      if (TerritoryRepository.isLocalOnly(row) || row.dirty) continue;

      if (row.ownerId == _player.id) {
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
