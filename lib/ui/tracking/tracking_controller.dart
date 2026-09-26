import 'dart:async';

import 'package:clipper2/clipper2.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/database.dart';
import '../../data/local/elevation_codec.dart';
import '../../data/photo_repository.dart';
import '../../data/providers.dart';
import '../../data/territory_repository.dart';
import '../../device/device_sensors.dart';
import '../../geo/lat_lng.dart';
import '../../geo/loop_detector.dart';
import '../../geo/projection.dart';
import '../../geo/territory_engine.dart';
import '../../location/fused_source.dart';
import '../../location/location_access.dart';
import '../../location/fix_gate.dart';
import '../../location/location_source.dart';
import '../../location/replay_source.dart';
import '../../sensor/barometer.dart';
import '../../sensor/cadence_analyzer.dart';

/// A finished run that has not been committed yet.
///
/// Holds everything the summary screen needs and everything a commit needs, so that between
/// finishing and saving the world is untouched: a discarded run must leave no trace, and that
/// is only true if nothing was written in the first place.
class PendingRun {
  /// The claim geometry, geographic. Committed verbatim on save.
  ///
  /// Null when the run ended without closing a loop. Such a run is still a run — it is offered,
  /// saved and listed like any other — it simply took no ground, so there is nothing to commit
  /// and nothing to steal.
  final PathsD? claim;

  /// The metre frame this run was projected about — the run's first accepted fix.
  final LatLng reference;

  final List<LatLng> track;

  /// What this run enclosed, or zero when no loop closed. Not the same as the total holding
  /// after a save, which folds this into whatever the runner already held.
  final double areaM2;

  /// Computed by `previewClaim`, which resolves against the rivals without writing.
  final double stolenAreaM2;
  final int stolenFromCount;

  final double distanceM;
  final Duration duration;
  final int steps;
  final double elevationGainM;

  /// The profile the run traced, for the chart on the summary screen.
  final List<ElevationSample> elevationSeries;

  final bool verified;
  final double plausibleRatio;
  final DateTime startedAt;

  /// Taken during the run. Filed against it on Save, deleted on Discard.
  final List<PendingPhoto> photos;

  const PendingRun({
    required this.claim,
    required this.reference,
    required this.track,
    required this.areaM2,
    required this.stolenAreaM2,
    required this.stolenFromCount,
    required this.distanceM,
    required this.duration,
    required this.steps,
    required this.elevationGainM,
    required this.elevationSeries,
    required this.verified,
    required this.plausibleRatio,
    required this.startedAt,
    this.photos = const [],
  });

  /// Whether this run took ground. False for a run that never closed its loop.
  bool get claimedGround => claim != null;
}

/// Everything the tracking screen draws.
class TrackingState {
  final bool running;
  final bool closed;
  final List<LatLng> track;

  /// The live claim preview, in geographic coordinates. Null until the loop closes, and
  /// cleared once the claim has been committed and comes back through [territories].
  final PathsD? claim;

  /// Every stored territory — the runner's own and everyone else's.
  final List<Territory> territories;

  final String playerId;
  final double distanceM;
  final double closureProgress;

  /// True while the run is back within [LoopDetector.closeRadiusM] of its start, so ending it
  /// now would claim the ground inside. Does not end the run by itself.
  final bool canClaim;

  /// Metres from the latest fix back to where the run began. Zero before there is a track.
  final double distanceToStartM;

  final double claimedAreaM2;
  final double stolenAreaM2;
  final int stolenFromCount;
  final bool verified;
  final String status;

  /// Where permission stands. The map renders a designed state for each value rather than a
  /// blank grey field.
  final LocationAccess access;

  /// The session's anchor: the first place we knew the runner to be. Rivals are seeded around
  /// it and the map opens on it.
  final LatLng? origin;

  /// The latest accepted fix, for the "you are here" marker and its accuracy circle.
  final Fix? currentFix;

  /// Degrees from magnetic north, or null when there is no compass.
  final double? headingDeg;

  final int steps;
  final double elevationGainM;

  /// Every altitude reading so far, against the distance it was taken at. Accumulated per fix
  /// rather than per barometer tick, so the profile has one point per track vertex.
  final List<ElevationSample> elevationSeries;

  /// Height above sea level right now — smoothed barometer when there is one, else whatever
  /// the receiver reports. Null until a run produces a reading.
  final double? altitudeM;

  /// When the current run began. The live counter ticks elapsed time from this on its own
  /// clock, so the state is not rewritten once a second for a number nobody stores.
  final DateTime? startedAt;

  /// What this device actually has. Anything false hides its feature entirely.
  final SensorAvailability availability;

  /// True while the bundled GPX is being played instead of real GPS.
  final bool replaying;

  /// A closed loop awaiting Save or Discard. Non-null means the summary is owed.
  final PendingRun? pendingRun;

  /// Photos taken so far in the current run.
  final List<PendingPhoto> photos;

  const TrackingState({
    required this.running,
    required this.closed,
    required this.track,
    required this.claim,
    required this.territories,
    required this.playerId,
    required this.distanceM,
    required this.closureProgress,
    required this.canClaim,
    required this.distanceToStartM,
    required this.claimedAreaM2,
    required this.stolenAreaM2,
    required this.stolenFromCount,
    required this.verified,
    required this.status,
    required this.access,
    required this.origin,
    required this.currentFix,
    required this.headingDeg,
    required this.steps,
    required this.elevationGainM,
    required this.elevationSeries,
    required this.altitudeM,
    required this.startedAt,
    required this.availability,
    required this.replaying,
    required this.pendingRun,
    required this.photos,
  });

  const TrackingState.initial()
    : running = false,
      closed = false,
      track = const [],
      claim = null,
      territories = const [],
      playerId = '',
      distanceM = 0,
      closureProgress = 0,
      canClaim = false,
      distanceToStartM = 0,
      claimedAreaM2 = 0,
      stolenAreaM2 = 0,
      stolenFromCount = 0,
      verified = true,
      status = 'Loading…',
      access = LocationAccess.notRequested,
      origin = null,
      currentFix = null,
      headingDeg = null,
      steps = 0,
      elevationGainM = 0,
      elevationSeries = const [],
      altitudeM = null,
      startedAt = null,
      availability = const SensorAvailability.none(),
      replaying = false,
      pendingRun = null,
      photos = const [];

  /// True once there is somewhere to point the map at.
  bool get hasLocation => currentFix != null || origin != null;

  TrackingState copyWith({
    bool? running,
    bool? closed,
    List<LatLng>? track,
    PathsD? claim,
    bool clearClaim = false,
    List<Territory>? territories,
    String? playerId,
    double? distanceM,
    double? closureProgress,
    bool? canClaim,
    double? distanceToStartM,
    double? claimedAreaM2,
    double? stolenAreaM2,
    int? stolenFromCount,
    bool? verified,
    String? status,
    LocationAccess? access,
    LatLng? origin,
    Fix? currentFix,
    double? headingDeg,
    int? steps,
    double? elevationGainM,
    List<ElevationSample>? elevationSeries,
    double? altitudeM,
    bool clearAltitude = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    SensorAvailability? availability,
    bool? replaying,
    PendingRun? pendingRun,
    bool clearPending = false,
    List<PendingPhoto>? photos,
  }) => TrackingState(
    running: running ?? this.running,
    closed: closed ?? this.closed,
    track: track ?? this.track,
    claim: clearClaim ? null : (claim ?? this.claim),
    territories: territories ?? this.territories,
    playerId: playerId ?? this.playerId,
    distanceM: distanceM ?? this.distanceM,
    closureProgress: closureProgress ?? this.closureProgress,
    canClaim: canClaim ?? this.canClaim,
    distanceToStartM: distanceToStartM ?? this.distanceToStartM,
    claimedAreaM2: claimedAreaM2 ?? this.claimedAreaM2,
    stolenAreaM2: stolenAreaM2 ?? this.stolenAreaM2,
    stolenFromCount: stolenFromCount ?? this.stolenFromCount,
    verified: verified ?? this.verified,
    status: status ?? this.status,
    access: access ?? this.access,
    origin: origin ?? this.origin,
    currentFix: currentFix ?? this.currentFix,
    headingDeg: headingDeg ?? this.headingDeg,
    steps: steps ?? this.steps,
    elevationGainM: elevationGainM ?? this.elevationGainM,
    elevationSeries: elevationSeries ?? this.elevationSeries,
    altitudeM: clearAltitude ? null : (altitudeM ?? this.altitudeM),
    startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    availability: availability ?? this.availability,
    replaying: replaying ?? this.replaying,
    pendingRun: clearPending ? null : (pendingRun ?? this.pendingRun),
    photos: photos ?? this.photos,
  );
}

/// Fallback anchor, used only when the device will not tell us where it is.
///
/// Without it a first launch with location refused has nowhere to put the map or the seeded
/// rivals, and the app opens on a grey field at zoom 0.
const LatLng fallbackOrigin = LatLng(50.7217, 10.4483);

/// Below this, a run is not offered for saving at all.
///
/// An accidental tap on Start followed by a tap on Stop is not a run, and history filled
/// with ten-metre fragments is worse than history with a gap in it.
const double minimumRunM = 50.0;

/// The recorded routes the replay harness can play, by the name shown when choosing one.
const Map<String, String> replayRoutes = {
  'Demo loop': 'assets/demo_loop.gpx',
  'Figure eight': 'assets/figure_eight.gpx',
};

/// A name for a run the user did not bother to name.
///
/// Pre-filled rather than required, so Save is one tap: naming a run is something people do
/// occasionally, not every time.
String defaultRunTitle([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  // Night wraps midnight, so it is checked first. Without it a 00:30 run is filed as a morning
  // run — the one hour of the day nobody would call morning.
  if (hour < 5 || hour >= 22) return 'Night run';
  if (hour < 12) return 'Morning run';
  if (hour < 18) return 'Afternoon run';
  return 'Evening run';
}

class TrackingController extends Notifier<TrackingState> {
  LocationSource? _source;
  StreamSubscription<Fix>? _subscription;
  StreamSubscription<List<Territory>>? _territorySubscription;
  TerritoryRepository? _repository;

  StreamSubscription<({double x, double y, double z, int timestampNanos})>?
  _accelerometer;
  StreamSubscription<double>? _barometer;
  StreamSubscription<int>? _pedometer;
  StreamSubscription<double>? _compass;

  final CadenceAnalyzer _cadence = CadenceAnalyzer();
  final PlausibilityTracker _plausibility = PlausibilityTracker();
  final Haptics _haptics = const Haptics();

  /// The reference point this run's geometry is projected about. Set from the run's first
  /// accepted fix, because projecting about a point hundreds of kilometres away distorts the
  /// metre frame the areas are measured in.
  LatLng? _runOrigin;

  /// Sensor probing outlives a short-lived container — a widget test disposes while the
  /// probe is still waiting out its timeout. Touching `ref` or `state` after that throws,
  /// so every late callback checks this first.
  bool _disposed = false;

  /// When the current run began, for the summary's elapsed time.
  DateTime? _startedAt;

  /// What the status line says while running and away from the start. Restored when the
  /// runner heads back out past the claim radius.
  String _runStatus = 'Tracking…';

  /// Set while a run is being ended, so a second End cannot resolve the same run twice.
  bool _ending = false;

  int? _stepBase;
  double _smoothedAltitude = 0;
  double? _lastGainAltitude;

  @override
  TrackingState build() {
    ref.onDispose(_teardown);
    unawaited(_bootstrap());
    return const TrackingState.initial();
  }

  /// Storage first, then location, then sensors — each independent of the last, so a refusal
  /// at any step leaves the others working.
  ///
  /// Errors are caught and surfaced rather than left to an unawaited future: a database that
  /// fails to open would otherwise leave the UI on "Loading…" forever with nothing said.
  Future<void> _bootstrap() async {
    try {
      final repository = await ref.read(territoryRepositoryProvider.future);
      final player = await ref.read(playerIdentityProvider.future);
      _repository = repository;

      _territorySubscription = repository.watchTerritories().listen((rows) {
        state = state.copyWith(territories: rows);
      });

      state = state.copyWith(status: 'Locating…');

      final origin = await _resolveOrigin();
      await repository.seedRivalsAround(origin);

      // playerId is set last, and only here: it is the signal that bootstrap finished. Setting
      // it earlier lets a caller act on a world whose rivals have not been seeded yet.
      state = state.copyWith(
        playerId: player.id,
        origin: origin,
        status: state.access == LocationAccess.granted
            ? 'Ready'
            : 'Ready — location unavailable, showing the demo area',
      );

      unawaited(_startSensors());
    } catch (error, stack) {
      debugPrint('ClaimTrek: bootstrap failed: $error\n$stack');
      state = state.copyWith(status: 'Storage unavailable: $error');
    }
  }

  /// Asks for location and takes one fix, falling back to [fallbackOrigin].
  ///
  /// Every failure mode here is ordinary — refused, switched off, indoors with no fix, or a
  /// host with no location plugin at all — so none of them may take down the app.
  Future<LatLng> _resolveOrigin() async {
    try {
      final gate = ref.read(locationAccessGateProvider);
      final access = await gate.request();
      state = state.copyWith(access: access);

      if (access != LocationAccess.granted) return fallbackOrigin;

      final fix = await FusedSource.currentFix();
      if (fix == null) return fallbackOrigin;

      state = state.copyWith(currentFix: fix);
      return fix.point;
    } catch (error) {
      debugPrint('ClaimTrek: location unavailable: $error');
      return fallbackOrigin;
    }
  }

  /// Re-asks after a refusal, from the button the error state offers.
  Future<void> retryLocation() async {
    final origin = await _resolveOrigin();
    if (state.access == LocationAccess.granted) {
      state = state.copyWith(origin: origin, status: 'Ready');
    }
  }

  Future<void> openSettings() async {
    final gate = ref.read(locationAccessGateProvider);
    if (state.access == LocationAccess.servicesDisabled) {
      await gate.openLocationSettings();
    } else {
      await gate.openAppSettings();
    }
  }

  /// Subscribes only to sensors the probe found. A stream for an absent sensor never emits, so
  /// subscribing blind would leave features waiting forever on data that is not coming.
  Future<void> _startSensors() async {
    final SensorAvailability availability;
    try {
      availability = await ref.read(sensorAvailabilityProvider.future);
    } catch (error) {
      debugPrint('ClaimTrek: sensor probe failed: $error');
      return;
    }
    if (_disposed) return;
    state = state.copyWith(availability: availability);

    if (availability.accelerometer) {
      _accelerometer = AccelerometerSource().start().listen(
        (e) => _cadence.onAcceleration(e.x, e.y, e.z, e.timestampNanos),
        onError: (Object _) {},
      );
    }

    if (availability.barometer) {
      _barometer = BarometerSource().start().listen(
        _onPressure,
        onError: (Object _) {},
      );
    }

    if (availability.pedometer) {
      _pedometer = PedometerSource().start().listen(
        _onSteps,
        onError: (Object _) {},
      );
    }

    if (availability.compass) {
      _compass = CompassSource().start().listen(
        (heading) {
          if (_disposed) return;
          state = state.copyWith(headingDeg: heading);
        },
        onError: (Object _) {},
      );
    }
  }

  final FixGate _gate = FixGate();

  void _onPressure(double hpa) {
    if (_disposed || !state.running) return;
    final altitude = Barometer.altitudeMetres(hpa);
    _smoothedAltitude = Barometer.smooth(_smoothedAltitude, altitude);
    state = state.copyWith(altitudeM: _smoothedAltitude);

    final previous = _lastGainAltitude;
    if (previous == null) {
      _lastGainAltitude = _smoothedAltitude;
      return;
    }

    final gain = Barometer.accumulateGain(previous, _smoothedAltitude);
    if (gain > 0) {
      _lastGainAltitude = _smoothedAltitude;
      state = state.copyWith(elevationGainM: state.elevationGainM + gain);
    }
  }

  /// The platform counter runs since boot and never resets, so a run's own total is the
  /// difference from the first reading after it started.
  void _onSteps(int total) {
    if (_disposed || !state.running) return;
    _stepBase ??= total;
    state = state.copyWith(steps: total - _stepBase!);
  }

  /// Start a real run.
  Future<void> start() => _begin(
    FusedSource(),
    replaying: false,
    status: 'Tracking…',
  );

  /// Play a bundled GPX route instead of reading GPS. [asset] is one of [replayRoutes].
  ///
  /// Not a demo toy: debugging polygon clipping by walking around a car park is not a workable
  /// loop, so the app has to stay drivable indoors. Reachable from a long-press on the start
  /// control.
  Future<void> startReplay({
    String asset = 'assets/demo_loop.gpx',
    int speedX = 10,
  }) async {
    final gpx = await rootBundle.loadString(asset);
    await _begin(
      ReplaySource.fromGpx(gpx, speedX: speedX),
      replaying: true,
      status: 'Replaying a recorded route at ${speedX}x',
    );
  }

  Future<void> _begin(
    LocationSource source, {
    required bool replaying,
    required String status,
  }) async {
    if (state.running) return;
    await _stopSources();

    _cadence.reset();
    _plausibility.reset();
    _runOrigin = null;
    _startedAt = DateTime.now();
    _runStatus = status;
    _ending = false;
    _stepBase = null;
    _lastGainAltitude = null;
    _smoothedAltitude = 0;

    // Or the last run's final position judges this run's first fix as a teleport, and the
    // track never starts.
    _gate.reset();

    state = state.copyWith(
      running: true,
      closed: false,
      track: const [],
      clearClaim: true,
      distanceM: 0,
      closureProgress: 0,
      canClaim: false,
      distanceToStartM: 0,
      claimedAreaM2: 0,
      stolenAreaM2: 0,
      stolenFromCount: 0,
      steps: 0,
      elevationGainM: 0,
      elevationSeries: const [],
      clearAltitude: true,
      startedAt: _startedAt,
      verified: true,
      photos: const [],
      replaying: replaying,
      status: status,
    );

    _source = source;
    _subscription = source.start().listen(
      _onFix,
      onDone: _onExhausted,
      onError: (Object error) {
        state = state.copyWith(running: false, status: 'Lost GPS: $error');
      },
    );
  }

  void _onFix(Fix fix) {
    // The same gate real GPS goes through: one 60 m outlier turns a neat loop into a spike.
    if (!LocationSource.accept(fix)) return;

    // And the half that needs history. `accept` judges a fix alone, so it cannot see the
    // failure that actually distorts a claim: a fix 80 m out that reports good accuracy and a
    // walking pace. Only the distance from the previous fix, over the time between them, does.
    final verdict = _gate.admit(fix);
    if (!verdict.accepted) return;

    // Anti-cheat abstains when it has no evidence. With no accelerometer, `cadenceHz` is a flat
    // zero, which `isPlausible` reads as "moving with no gait at all", i.e. a vehicle. Recording
    // that would mark every run on such a device unverified, inverting the rule that a missing
    // sensor hides its feature rather than failing the runner.
    if (state.availability.accelerometer) {
      _plausibility.record(
        CadenceAnalyzer.isPlausible(
          speedMs: fix.speedMs,
          cadenceHz: _cadence.cadenceHz,
        ),
      );
    }

    _runOrigin ??= fix.point;

    final previousPoint = state.track.isEmpty ? null : state.track.last;
    final track = [...state.track, fix.point];

    // Accumulated per leg rather than remeasured. Walking the whole track on every fix is what
    // makes a long run quadratic, and distance is a running total by nature.
    final distanceM = verdict.creditsDistance && previousPoint != null
        ? state.distanceM + Projection.haversine(previousPoint, fix.point)
        : state.distanceM;

    // Being back at the start no longer ends the run: the runner may keep going to take in
    // ground on the far side. It only decides what ending the run *would* do.
    final canClaim = LoopDetector.isClosed(track, travelledM: distanceM);
    if (canClaim && !state.canClaim) unawaited(_haptics.loopClosed());

    // The barometer owns altitude when it exists; GPS height is the fallback, and a poor one
    // (tens of metres out), but a rough number beats an empty row.
    final gpsAltitude = state.availability.barometer ? null : fix.altitudeM;

    // Whichever source is actually feeding altitude: the barometer has already written its
    // smoothed value into the state, and `gpsAltitude` is non-null only when there is no
    // barometer to prefer.
    final altitudeM = gpsAltitude ?? state.altitudeM;
    final elevationSeries = altitudeM == null
        ? state.elevationSeries
        : [
            ...state.elevationSeries,
            ElevationSample(distanceM: distanceM, altitudeM: altitudeM),
          ];

    state = state.copyWith(
      track: track,
      currentFix: fix,
      distanceM: distanceM,
      closureProgress: LoopDetector.closureProgress(track, travelledM: distanceM),
      canClaim: canClaim,
      distanceToStartM: LoopDetector.distanceToStart(track),
      verified: _plausibility.verified,
      altitudeM: gpsAltitude,
      elevationSeries: elevationSeries,
      status: canClaim ? 'Back at the start — hold End to claim' : _runStatus,
    );
  }

  /// Closes the loop and stops. Nothing is written.
  ///
  /// The claim is resolved against the rivals by `previewClaim`, which computes what would be
  /// taken without taking it, and parked as a [PendingRun]. Storage is untouched until the
  /// runner presses Save — which is the whole reason Discard can be a real choice.
  Future<void> _finish(List<LatLng> track) async {
    unawaited(_haptics.loopClosed());

    final reference = _runOrigin ?? state.origin ?? fallbackOrigin;
    final claim = TerritoryEngine.buildTerritoryGeographic(track, reference);
    final repository = _repository;

    // An out-and-back can end near the start and still enclose nothing. The runner asked to
    // end the run, so it is still offered — just without ground.
    if (claim == null || repository == null) {
      _offerRunWithoutClaim();
      return;
    }

    final startedAt = _startedAt ?? DateTime.now();
    final preview = await repository.previewClaim(claim);

    state = state.copyWith(
      closed: true,
      running: false,
      // Drawn on the map behind the summary, so the ground being offered is visible.
      claim: claim,
      claimedAreaM2: TerritoryEngine.areaM2(claim),
      stolenAreaM2: preview.stolenAreaM2,
      stolenFromCount: preview.stolenFromCount,
      status: 'Loop closed — save or discard',
      pendingRun: PendingRun(
        claim: claim,
        reference: reference,
        track: track,
        areaM2: TerritoryEngine.areaM2(claim),
        stolenAreaM2: preview.stolenAreaM2,
        stolenFromCount: preview.stolenFromCount,
        distanceM: state.distanceM,
        duration: DateTime.now().difference(startedAt),
        steps: state.steps,
        elevationGainM: state.elevationGainM,
        elevationSeries: state.elevationSeries,
        verified: state.verified,
        plausibleRatio: _plausibility.ratio,
        startedAt: startedAt,
        photos: state.photos,
      ),
    );
  }

  /// Commit the pending run: the territory, the steal, and the run record.
  ///
  /// The claim is committed exactly as it was previewed, from the same geometry and the same
  /// reference, so the numbers the runner agreed to are the numbers that land.
  Future<void> saveRun({String? title}) async {
    final pending = state.pendingRun;
    final repository = _repository;
    if (pending == null || repository == null) return;

    // A run that closed no loop commits no territory: there is nothing to take and nobody to
    // take it from. It is still recorded as a run.
    final claim = pending.claim;
    final outcome = claim == null
        ? null
        : await repository.commitClaim(
            claimGeographic: claim,
            reference: pending.reference,
            verified: pending.verified,
          );

    final runId = const Uuid().v4();
    final saved = await repository.saveRun(
      id: runId,
      title: (title ?? '').trim().isEmpty ? defaultRunTitle() : title!.trim(),
      isPublic: false,
      startedAt: pending.startedAt.millisecondsSinceEpoch,
      durationMs: pending.duration.inMilliseconds,
      distanceM: pending.distanceM,
      steps: pending.steps,
      elevationGainM: pending.elevationGainM,
      elevationSeries: pending.elevationSeries,
      areaM2: pending.areaM2,
      verified: pending.verified,
      plausibleRatio: pending.plausibleRatio,
      reference: pending.reference,
      track: pending.track,
    );

    await ref.read(photoRepositoryProvider).attachToRun(runId, pending.photos);

    // After the local commit, never before it: a player with no account or no signal has still
    // saved their run, and SyncService is a no-op for them.
    final sync = await ref.read(syncServiceProvider.future);
    await sync.onRunSaved(saved);

    // Committed ground arrives through watchTerritories, so the preview would be drawn twice.
    state = state.copyWith(
      clearClaim: true,
      clearPending: true,
      photos: const [],
      claimedAreaM2: outcome?.areaM2 ?? 0,
      stolenAreaM2: outcome?.stolenAreaM2 ?? 0,
      stolenFromCount: outcome?.stolenFromCount ?? 0,
      status: outcome == null ? 'Run saved' : 'Claimed',
    );
  }

  /// Throw the run away. Nothing was written, so there is nothing to undo.
  ///
  /// The track goes too. The summary promises that discarding leaves the map exactly as it was,
  /// and a trace left drawn across it is not that.
  void discardRun() {
    _gate.reset();
    final photos = state.pendingRun?.photos ?? state.photos;
    if (photos.isNotEmpty) {
      unawaited(ref.read(photoRepositoryProvider).discard(photos));
    }
    state = state.copyWith(
      photos: const [],
      clearClaim: true,
      clearPending: true,
      closed: false,
      track: const [],
      distanceM: 0,
      closureProgress: 0,
      canClaim: false,
      distanceToStartM: 0,
      claimedAreaM2: 0,
      stolenAreaM2: 0,
      stolenFromCount: 0,
      steps: 0,
      elevationGainM: 0,
      elevationSeries: const [],
      clearAltitude: true,
      clearStartedAt: true,
      status: 'Run discarded',
    );
  }

  // ═══ TESTING ONLY — see lib/testing_tools.dart ══════════════════════════════════════════
  /// Clears all claimed ground and restores the rivals, so a loop can be captured again.
  ///
  /// Refused mid-run or with a run awaiting Save: the pending claim was previewed against the
  /// rivals as they stand, and resetting under it would commit numbers that no longer match.
  Future<bool> resetGroundForTesting() async {
    final repository = _repository;
    if (repository == null || state.running || state.pendingRun != null) {
      return false;
    }
    await repository.resetGroundForTesting(state.origin ?? fallbackOrigin);
    final sync = await ref.read(syncServiceProvider.future);
    await sync.onGroundChanged();
    state = state.copyWith(claimedAreaM2: 0, stolenAreaM2: 0, stolenFromCount: 0);
    return true;
  }
  // ═══ END TESTING ONLY ════════════════════════════════════════════════════════════════════

  /// Files a photo just taken with the camera against the run in progress.
  ///
  /// [cameraPath] is the camera's own output, which is moved into the app's storage first: the
  /// camera writes to a cache the OS is free to clear before the run is saved.
  Future<void> addPhoto(String cameraPath) async {
    if (!state.running && state.pendingRun == null) return;
    final kept = await ref.read(photoRepositoryProvider).keep(cameraPath);
    final photo = PendingPhoto(
      filePath: kept,
      takenAt: DateTime.now(),
      point: state.track.isEmpty ? state.currentFix?.point : state.track.last,
      distanceM: state.distanceM,
    );

    // The run may have ended while the camera was open. The photo still belongs to it.
    final pending = state.pendingRun;
    if (pending != null) {
      state = state.copyWith(
        pendingRun: PendingRun(
          claim: pending.claim,
          reference: pending.reference,
          track: pending.track,
          areaM2: pending.areaM2,
          stolenAreaM2: pending.stolenAreaM2,
          stolenFromCount: pending.stolenFromCount,
          distanceM: pending.distanceM,
          duration: pending.duration,
          steps: pending.steps,
          elevationGainM: pending.elevationGainM,
          elevationSeries: pending.elevationSeries,
          verified: pending.verified,
          plausibleRatio: pending.plausibleRatio,
          startedAt: pending.startedAt,
          photos: [...pending.photos, photo],
        ),
      );
      return;
    }
    state = state.copyWith(photos: [...state.photos, photo]);
  }

  /// The replay has run out of fixes. The run stays open: ending it is the runner's decision,
  /// and the replay is how that decision gets tested indoors.
  void _onExhausted() {
    if (_disposed || !state.running) return;
    state = state.copyWith(
      status: state.canClaim
          ? 'Replay finished — hold End to claim'
          : 'Replay finished — hold End to finish',
    );
  }

  /// End the run. The only way a run ends.
  ///
  /// Back within [LoopDetector.closeRadiusM] of the start, the whole track closes into a claim
  /// and is previewed for Save or Discard. Anywhere else the run is offered without ground.
  Future<void> stop() async {
    if (_ending || state.pendingRun != null) return;
    _ending = true;
    try {
      await _stopSources();
      final track = state.track;
      if (LoopDetector.isClosed(track, travelledM: state.distanceM)) {
        state = state.copyWith(status: 'Closing the loop…');
        await _finish(track);
      } else {
        _offerRunWithoutClaim();
      }
    } finally {
      _ending = false;
    }
  }

  /// Offer a run that never closed its loop.
  ///
  /// It took no ground, so there is no claim, nothing to steal and no area — but it is still a
  /// run that happened, and the runner should get to keep it. The summary shows the path and
  /// the effort, and Save records it with a zero area.
  void _offerRunWithoutClaim() {
    if (state.closed || state.pendingRun != null) {
      state = state.copyWith(running: false);
      return;
    }

    if (state.track.length < 2 || state.distanceM < minimumRunM) {
      state = state.copyWith(running: false, status: 'Stopped');
      return;
    }

    final startedAt = _startedAt ?? DateTime.now();

    state = state.copyWith(
      running: false,
      status: 'Run ended without closing a loop',
      pendingRun: PendingRun(
        claim: null,
        reference: _runOrigin ?? state.origin ?? fallbackOrigin,
        track: state.track,
        areaM2: 0,
        stolenAreaM2: 0,
        stolenFromCount: 0,
        distanceM: state.distanceM,
        duration: DateTime.now().difference(startedAt),
        steps: state.steps,
        elevationGainM: state.elevationGainM,
        elevationSeries: state.elevationSeries,
        verified: state.verified,
        plausibleRatio: _plausibility.ratio,
        startedAt: startedAt,
        photos: state.photos,
      ),
    );
  }

  Future<void> _stopSources() async {
    await _subscription?.cancel();
    _subscription = null;
    await _source?.stop();
    _source = null;
  }

  Future<void> _teardown() async {
    _disposed = true;
    await _stopSources();
    await _territorySubscription?.cancel();
    _territorySubscription = null;
    await _accelerometer?.cancel();
    await _barometer?.cancel();
    await _pedometer?.cancel();
    await _compass?.cancel();
  }
}

final trackingControllerProvider =
    NotifierProvider<TrackingController, TrackingState>(
      TrackingController.new,
    );
