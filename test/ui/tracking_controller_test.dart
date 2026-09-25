import 'dart:io';

import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/photo_repository.dart';
import 'package:claimtrek/data/providers.dart';
import 'package:claimtrek/device/device_sensors.dart';
import 'package:claimtrek/geo/territory_engine.dart';
import 'package:claimtrek/ui/tracking/tracking_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end over the whole capture pipeline: GPX asset -> fixes -> accuracy/speed filter ->
/// track -> loop closure -> polygon build -> claim preview -> Save or Discard -> persistence.
///
/// Everything except the map widget and real GPS, and it runs in a couple of seconds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClaimTrekDatabase db;
  late ProviderContainer container;
  late Directory temp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = ClaimTrekDatabase.forTesting(NativeDatabase.memory());
    temp = Directory.systemTemp.createTempSync('claimtrek_run_');
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // A test host has no documents directory to ask path_provider for.
        photoRepositoryProvider.overrideWith(
          (ref) => PhotoRepository(db, () async => Directory('${temp.path}/run_photos')),
        ),
        // A test host has no sensors, and probing for them on one raises an unhandled
        // method-channel error from inside the plugin. Stating it outright is both honest
        // and exactly the no-hardware path these tests exist to cover.
        sensorAvailabilityProvider.overrideWith(
          (ref) async => const SensorAvailability.none(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await temp.delete(recursive: true);
  });

  TrackingController controllerOf() =>
      container.read(trackingControllerProvider.notifier);

  TrackingState stateOf() => container.read(trackingControllerProvider);

  /// The controller bootstraps asynchronously; nothing can start until storage is ready.
  /// On a test host the location and sensor plugins are absent, so bootstrap falls through
  /// to the demo origin and an empty sensor set — which is exactly the no-hardware path.
  Future<void> waitForReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (stateOf().playerId.isNotEmpty) return;
    }
    fail('the controller never finished bootstrapping');
  }

  /// Replays the fixture until the runner is back at the start and the loop could close.
  Future<void> runUntilClaimable() async {
    await waitForReady();
    await controllerOf().startReplay(speedX: 400);

    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final state = stateOf();
      if (state.canClaim) return;
      if (!state.running) fail('the run ended on its own: ${state.status}');
    }
    fail('the replay never came back to the start');
  }

  /// Replays the fixture back to the start, then ends the run — the hold on End.
  Future<PendingRun> runUntilPending() async {
    await runUntilClaimable();
    await controllerOf().stop();
    final pending = stateOf().pendingRun;
    if (pending == null) fail('ending at the start offered nothing: ${stateOf().status}');
    return pending;
  }

  /// `watchTerritories` delivers on its own tick, so committed ground reaches the state a
  /// moment after the write returns.
  Future<void> waitForOwnTerritory() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final state = stateOf();
      if (state.territories.any((t) => t.ownerId == state.playerId)) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('committed ground never arrived through the territory stream');
  }

  Future<double> rivalAreaTotal() async {
    final playerId = stateOf().playerId;
    final rows = await db.territoryDao.getAll();
    return rows
        .where((t) => t.ownerId != playerId)
        .fold<double>(0, (sum, t) => sum + t.areaM2);
  }

  /// Replays only far enough to be a real run, then stops without closing.
  Future<PendingRun> runAndStopEarly() async {
    await waitForReady();
    await controllerOf().startReplay(speedX: 400);

    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (stateOf().distanceM > 300) break;
      if (stateOf().pendingRun != null) fail('the loop closed before we could stop');
    }

    await controllerOf().stop();
    final pending = stateOf().pendingRun;
    if (pending == null) fail('stopping mid-run offered nothing: ${stateOf().status}');
    return pending;
  }

  test('a run stopped before closing is still offered', () async {
    final pending = await runAndStopEarly();

    expect(pending.claimedGround, isFalse, reason: 'no loop, no ground');
    expect(pending.claim, isNull);
    expect(pending.areaM2, 0);
    expect(pending.stolenAreaM2, 0);
    expect(pending.distanceM, greaterThan(300), reason: 'the effort is still recorded');
    expect(pending.track.length, greaterThan(2), reason: 'the path is the whole record');
  });

  test('saving an unclosed run records the run and claims nothing', () async {
    await waitForReady();
    final before = await db.territoryDao.getAll();

    await runAndStopEarly();
    await controllerOf().saveRun(title: 'Aborted run');

    final runs = await db.runDao.watchAll().first;
    expect(runs, hasLength(1));
    expect(runs.single.title, 'Aborted run');
    expect(runs.single.areaM2, 0, reason: 'nothing was enclosed');
    expect(
      runs.single.encodedPath,
      isNotEmpty,
      reason: 'the path is what makes it worth keeping',
    );

    final after = await db.territoryDao.getAll();
    expect(
      after.map((t) => t.id).toList(),
      before.map((t) => t.id).toList(),
      reason: 'an unclosed run must not take or disturb any ground',
    );
    expect(
      after.any((t) => t.ownerId == stateOf().playerId),
      isFalse,
      reason: 'and it must not create a territory of its own',
    );
  });

  test('a run too short to matter is not offered at all', () async {
    // An accidental Start-then-Stop is not a run, and history full of ten-metre fragments is
    // worse than history with a gap in it.
    await waitForReady();
    await controllerOf().startReplay(speedX: 400);
    await controllerOf().stop();

    expect(stateOf().pendingRun, isNull);
    expect(stateOf().distanceM, lessThan(minimumRunM));
  });

  test('rivals are seeded once storage is ready', () async {
    await waitForReady();
    final state = stateOf();

    expect(state.territories, hasLength(3));
    expect(
      state.territories.where((t) => !t.verified),
      hasLength(1),
      reason: 'one unverified rival makes the faded style visible from the start',
    );
    expect(state.playerId, isNotEmpty);
  });

  test('coming back to the start does not end the run', () async {
    // The runner may want to carry on past the start and take in more ground, so reaching it
    // only says that ending now would claim.
    await runUntilClaimable();
    final state = stateOf();

    expect(state.running, isTrue, reason: 'only the End button ends a run');
    expect(state.closed, isFalse);
    expect(state.pendingRun, isNull, reason: 'nothing is offered until the run ends');
    expect(state.distanceToStartM, lessThan(69));
  });

  test('the replay running out leaves the run open until it is ended', () async {
    await waitForReady();
    await controllerOf().startReplay(speedX: 400);

    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (!stateOf().status.startsWith('Replay finished')) {
      if (DateTime.now().isAfter(deadline)) fail('the replay never finished');
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    expect(stateOf().running, isTrue);
    expect(stateOf().pendingRun, isNull);
    expect(stateOf().canClaim, isTrue, reason: 'the demo loop ends back at its start');

    await controllerOf().stop();
    expect(stateOf().pendingRun?.claimedGround, isTrue);
  });

  test('ending the run far from the start claims nothing', () async {
    final pending = await runAndStopEarly();
    expect(stateOf().canClaim, isFalse);
    expect(pending.claimedGround, isFalse);
  });

  test('ending the demo loop at its start closes it and offers a claim', () async {
    final pending = await runUntilPending();
    final state = stateOf();

    expect(state.closed, isTrue, reason: 'the demo loop must close');
    expect(state.running, isFalse, reason: 'tracking stops once the run is ended');

    // The fixture is a 420 x 260 m rounded rectangle, so a little under 105 000 m².
    expect(pending.areaM2, greaterThan(80000));
    expect(pending.areaM2, lessThan(115000));
    expect(pending.distanceM, greaterThan(1000));
    expect(pending.stolenFromCount, greaterThanOrEqualTo(1));
  });

  test('a run with no accelerometer is not marked unverified', () async {
    // Anti-cheat must abstain without evidence, not convict. A flat-zero cadence reads as
    // "moving with no gait", so recording it would fail every run on a phone with no
    // accelerometer — and every replayed run too.
    final pending = await runUntilPending();

    expect(
      pending.verified,
      isTrue,
      reason: 'a missing sensor hides its feature; it does not fail the runner',
    );
  });

  test('closing a loop writes nothing until Save', () async {
    await waitForReady();
    final before = await db.territoryDao.getAll();
    final beforeArea = before.fold<double>(0, (sum, t) => sum + t.areaM2);
    expect(beforeArea, greaterThan(0), reason: 'baseline must include the seeded rivals');

    final pending = await runUntilPending();
    expect(pending.stolenAreaM2, greaterThan(0), reason: 'the preview found ground to take');

    final after = await db.territoryDao.getAll();
    expect(
      after.map((t) => t.id).toList(),
      before.map((t) => t.id).toList(),
      reason: 'a previewed claim must not touch storage',
    );
    expect(
      after.fold<double>(0, (sum, t) => sum + t.areaM2),
      closeTo(beforeArea, 0.001),
      reason: 'no rival may lose ground before the runner presses Save',
    );
  });

  test('Discard leaves the world exactly as it was', () async {
    await waitForReady();
    final before = await db.territoryDao.getAll();
    final beforeArea = before.fold<double>(0, (sum, t) => sum + t.areaM2);

    await runUntilPending();
    controllerOf().discardRun();

    final after = await db.territoryDao.getAll();
    final state = stateOf();

    expect(after, hasLength(before.length));
    expect(
      after.fold<double>(0, (sum, t) => sum + t.areaM2),
      closeTo(beforeArea, 0.001),
    );
    expect(state.pendingRun, isNull);
    expect(state.claim, isNull, reason: 'the offered ground stops being drawn');
    expect(
      state.track,
      isEmpty,
      reason: 'the summary promises the map is left exactly as it was',
    );
    expect(state.distanceM, 0);
    expect(
      after.any((t) => t.ownerId == state.playerId),
      isFalse,
      reason: 'a discarded run leaves the runner holding nothing',
    );
  });

  test('Save commits the ground that was previewed', () async {
    await waitForReady();
    final beforeArea = await rivalAreaTotal();

    final pending = await runUntilPending();
    await controllerOf().saveRun(title: 'Test loop');

    final playerId = stateOf().playerId;
    final after = await db.territoryDao.getAll();
    final mine = after.where((t) => t.ownerId == playerId).toList();

    expect(mine, hasLength(1), reason: 'one runner reads as one holding');
    expect(
      TerritoryEngine.areaM2(TerritoryEngine.fromWkt(mine.single.wkt)!),
      closeTo(pending.areaM2, 5),
      reason: 'the stored WKT must reload into the ground that was offered',
    );

    expect(
      beforeArea - await rivalAreaTotal(),
      closeTo(pending.stolenAreaM2, 1.0),
      reason: 'what the rivals lost is what the preview promised',
    );
  });

  test('Save records the run itself, not only the territory', () async {
    await runUntilPending();
    await controllerOf().saveRun(title: 'Test loop');

    final runs = await db.runDao.watchAll().first;

    expect(runs, hasLength(1));
    expect(runs.single.title, 'Test loop');
    expect(runs.single.distanceM, greaterThan(1000));
    expect(runs.single.verified, isTrue);
    expect(runs.single.encodedPath, isNotEmpty);
  });

  test('an unnamed run still gets a name', () async {
    await runUntilPending();
    await controllerOf().saveRun(title: '   ');

    final runs = await db.runDao.watchAll().first;
    expect(runs.single.title, isNotEmpty);
  });

  test('the preview is cleared once the claim is committed', () async {
    await runUntilPending();
    await controllerOf().saveRun(title: 'Test loop');
    await waitForOwnTerritory();
    final state = stateOf();

    expect(
      state.claim,
      isNull,
      reason: 'committed ground arrives through the territory stream instead',
    );
    expect(state.pendingRun, isNull);
    expect(state.territories.any((t) => t.ownerId == state.playerId), isTrue);
  });

  test('saving twice cannot claim twice', () async {
    // The screen guards against a double tap, but the controller is the thing that must not
    // be claimable twice — a second commit would steal from the rivals all over again.
    await runUntilPending();
    await controllerOf().saveRun(title: 'Test loop');
    await controllerOf().saveRun(title: 'Test loop');

    final playerId = stateOf().playerId;
    final mine = (await db.territoryDao.getAll())
        .where((t) => t.ownerId == playerId);
    expect(mine, hasLength(1));
  });

  test('a running state carries what the live counter needs', () async {
    // The HUD ticks elapsed time itself from `startedAt`, and shows the altitude the run is
    // currently at — from GPS when there is no barometer, which is the case on a test host.
    await waitForReady();
    expect(stateOf().startedAt, isNull);
    expect(stateOf().altitudeM, isNull);

    await runAndStopEarly();

    final state = stateOf();
    expect(state.startedAt, isNotNull, reason: 'set when the run began');
    expect(state.altitudeM, isNotNull, reason: 'the fixture carries <ele>');
    expect(state.altitudeM, closeTo(320, 5));
  });

  test('a run builds an elevation profile as it goes', () async {
    await waitForReady();
    expect(stateOf().elevationSeries, isEmpty);

    await runAndStopEarly();

    final series = stateOf().elevationSeries;
    expect(series.length, greaterThan(1), reason: 'one sample per accepted fix');

    // Distance only ever grows — a profile that doubles back would draw a chart that folds
    // over itself.
    for (var i = 1; i < series.length; i++) {
      expect(
        series[i].distanceM,
        greaterThanOrEqualTo(series[i - 1].distanceM),
      );
    }

    expect(series.first.distanceM, closeTo(0, 0.001));
    // The fixture sits around 320 m; anything wildly off means the wrong source was read.
    for (final sample in series) {
      expect(sample.altitudeM, closeTo(320, 15));
    }
  });

  test('the profile reaches the summary through the pending run', () async {
    // The chart is drawn after the run, so the series has to survive the handoff — losing it
    // here would leave every saved run with an empty chart and no obvious cause.
    final pending = await runUntilPending();

    expect(pending.elevationSeries.length, greaterThan(1));
    expect(pending.elevationSeries.last.distanceM, greaterThan(200));
  });

  test('a discarded run takes its profile with it', () async {
    await runAndStopEarly();
    expect(stateOf().elevationSeries, isNotEmpty);

    controllerOf().discardRun();

    expect(stateOf().elevationSeries, isEmpty);
  });

  group('figure eight', () {
    test('passing through the start halfway keeps the run going', () async {
      await waitForReady();
      await controllerOf().startReplay(asset: 'assets/figure_eight.gpx', speedX: 400);

      // Wait for the first time the runner is back at the start, one lobe in.
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (!stateOf().canClaim) {
        if (DateTime.now().isAfter(deadline)) fail('never came back through the start');
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final atCrossing = stateOf().distanceM;
      expect(atCrossing, lessThan(900), reason: 'this is the crossing, not the finish');

      // Now let it carry on round the second lobe.
      while (!stateOf().status.startsWith('Replay finished')) {
        if (DateTime.now().isAfter(deadline)) fail('the replay never finished');
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(stateOf().running, isTrue, reason: 'nothing but End ends the run');
      expect(stateOf().distanceM, greaterThan(atCrossing + 400));
    });

    test('ending at the finish claims both lobes', () async {
      await waitForReady();
      await controllerOf().startReplay(asset: 'assets/figure_eight.gpx', speedX: 400);

      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (!stateOf().status.startsWith('Replay finished')) {
        if (DateTime.now().isAfter(deadline)) fail('the replay never finished');
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      await controllerOf().stop();
      final pending = stateOf().pendingRun!;

      // A lemniscate of half-width 250 m encloses 250^2 = 62 500 m², split over two lobes.
      // One lobe alone would be about half that.
      expect(pending.claim, hasLength(2), reason: 'a figure eight is two lobes');
      expect(pending.areaM2, closeTo(62500, 2500));
    });
  });

  group('photos', () {
    /// Stands in for the camera: a file in a cache directory.
    String cameraShot(String name) {
      final file = File('${temp.path}/$name')..writeAsBytesSync([1, 2, 3]);
      return file.path;
    }

    /// Starts a replay and lets it get somewhere, so a photo has a place and a distance.
    Future<void> runABit() async {
      await waitForReady();
      await controllerOf().startReplay(speedX: 400);
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (stateOf().distanceM < 150) {
        if (DateTime.now().isAfter(deadline)) fail('the replay never got going');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test('a photo taken mid-run records where and how far in', () async {
      await runABit();
      await controllerOf().addPhoto(cameraShot('one.jpg'));

      final photos = stateOf().photos;
      expect(photos, hasLength(1));
      expect(photos.single.point, isNotNull);
      expect(photos.single.distanceM, greaterThanOrEqualTo(150));
      expect(File(photos.single.filePath).existsSync(), isTrue);
    });

    test('Save files the photos against the saved run', () async {
      await runABit();
      await controllerOf().addPhoto(cameraShot('one.jpg'));
      await controllerOf().addPhoto(cameraShot('two.jpg'));
      await controllerOf().stop();
      expect(stateOf().pendingRun!.photos, hasLength(2));

      await controllerOf().saveRun(title: 'Photo run');

      final run = (await db.runDao.watchAll().first).single;
      final rows = await db.runPhotoDao.watchForRun(run.id).first;
      expect(rows, hasLength(2));
      expect(stateOf().photos, isEmpty, reason: 'the next run starts with none');
    });

    test('Discard deletes the photos and files nothing', () async {
      await runABit();
      await controllerOf().addPhoto(cameraShot('one.jpg'));
      final path = stateOf().photos.single.filePath;
      await controllerOf().stop();

      controllerOf().discardRun();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(File(path).existsSync(), isFalse, reason: 'a discarded run leaves no trace');
      expect(await db.runPhotoDao.watchAll().first, isEmpty);
    });

    test('a photo taken while not running is ignored', () async {
      await waitForReady();
      await controllerOf().addPhoto(cameraShot('stray.jpg'));
      expect(stateOf().photos, isEmpty);
    });
  });
}
