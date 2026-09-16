import 'package:claimtrek/data/local/database.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = ClaimTrekDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
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

  /// Replays the fixture until the loop closes and a decision is owed.
  Future<PendingRun> runUntilPending() async {
    await waitForReady();
    await controllerOf().startReplay(speedX: 400);

    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final pending = stateOf().pendingRun;
      if (pending != null) return pending;
      final state = stateOf();
      if (!state.running && state.track.isNotEmpty && !state.closed) {
        fail('the replay ended without closing: ${state.status}');
      }
    }
    fail('the replay never finished');
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

  test('replaying the demo loop closes it and offers a claim', () async {
    final pending = await runUntilPending();
    final state = stateOf();

    expect(state.closed, isTrue, reason: 'the demo loop must close');
    expect(state.running, isFalse, reason: 'tracking stops once the loop closes');

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
}
