import 'dart:async';

import 'package:clipper2/clipper2.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/database.dart';
import '../../data/local/elevation_codec.dart';
import '../../data/providers.dart';
import '../../data/territory_repository.dart';
import '../../data/territory_sync.dart';
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
import '../../location/simulated_runs.dart';
import '../../sensor/barometer.dart';
import '../../sensor/cadence_analyzer.dart';

class PendingRun {
  final PathsD? claim;

  final LatLng reference;

  final List<LatLng> track;

  final double areaM2;

  final double stolenAreaM2;
  final int stolenFromCount;

  final double distanceM;
  final Duration duration;
  final int steps;
  final double elevationGainM;

  final List<ElevationSample> elevationSeries;

  final bool verified;
  final double plausibleRatio;
  final DateTime startedAt;

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
  });

  bool get claimedGround => claim != null;
}

class TrackingState {
  final bool running;
  final bool closed;
  final List<LatLng> track;

  final PathsD? claim;

  final List<Territory> territories;

  final String playerId;
  final double distanceM;
  final double closureProgress;
  final double claimedAreaM2;
  final double stolenAreaM2;
  final int stolenFromCount;
  final bool verified;
  final String status;

  final LocationAccess access;

  final LatLng? origin;

  final Fix? currentFix;

  final double? headingDeg;

  final int steps;
  final double elevationGainM;

  final List<ElevationSample> elevationSeries;

  final double? altitudeM;

  final DateTime? startedAt;

  final SensorAvailability availability;

  final bool replaying;

  final PendingRun? pendingRun;

  const TrackingState({
    required this.running,
    required this.closed,
    required this.track,
    required this.claim,
    required this.territories,
    required this.playerId,
    required this.distanceM,
    required this.closureProgress,
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
      pendingRun = null;

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
  }) => TrackingState(
    running: running ?? this.running,
    closed: closed ?? this.closed,
    track: track ?? this.track,
    claim: clearClaim ? null : (claim ?? this.claim),
    territories: territories ?? this.territories,
    playerId: playerId ?? this.playerId,
    distanceM: distanceM ?? this.distanceM,
    closureProgress: closureProgress ?? this.closureProgress,
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
  );
}

const LatLng fallbackOrigin = LatLng(50.7217, 10.4483);

const double minimumRunM = 50.0;

String defaultRunTitle([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
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

  TerritorySync? _territorySync;

  StreamSubscription<({double x, double y, double z, int timestampNanos})>?
  _accelerometer;
  StreamSubscription<double>? _barometer;
  StreamSubscription<int>? _pedometer;
  StreamSubscription<double>? _compass;

  final CadenceAnalyzer _cadence = CadenceAnalyzer();
  final PlausibilityTracker _plausibility = PlausibilityTracker();
  final Haptics _haptics = const Haptics();

  LatLng? _runOrigin;

  bool _disposed = false;

  DateTime? _startedAt;

  int? _stepBase;
  double _smoothedAltitude = 0;
  double? _lastGainAltitude;

  @override
  TrackingState build() {
    ref.onDispose(_teardown);

    ref.listen(territoryRepositoryProvider, (_, _) {});
    ref.listen(syncServiceProvider, (_, _) {});

    ref.listen<AsyncValue<TerritorySync>>(territorySyncProvider, (_, next) {
      final sync = next.value;
      if (sync == null || identical(sync, _territorySync)) return;
      _territorySync = sync;
      _followTerritory();
      unawaited(sync.flush());
    }, fireImmediately: true);

    unawaited(_bootstrap());
    return const TrackingState.initial();
  }

  void _followTerritory() {
    final at = state.currentFix?.point ?? state.origin;
    if (at != null) _territorySync?.follow(at);
  }

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

      state = state.copyWith(
        playerId: player.id,
        origin: origin,
        status: state.access == LocationAccess.granted
            ? 'Ready'
            : 'Ready — location unavailable, showing the demo area',
      );

      _followTerritory();
      unawaited(_startSensors());
    } catch (error, stack) {
      debugPrint('ClaimTrek: bootstrap failed: $error\n$stack');
      state = state.copyWith(status: 'Storage unavailable: $error');
    }
  }

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

  Future<void> retryLocation() async {
    final origin = await _resolveOrigin();
    if (state.access == LocationAccess.granted) {
      state = state.copyWith(origin: origin, status: 'Ready');
      _followTerritory();
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
      _compass = CompassSource().start().listen((heading) {
        if (_disposed) return;
        state = state.copyWith(headingDeg: heading);
      }, onError: (Object _) {});
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

  void _onSteps(int total) {
    if (_disposed || !state.running) return;
    _stepBase ??= total;
    state = state.copyWith(steps: total - _stepBase!);
  }

  Future<void> start() =>
      _begin(FusedSource(), replaying: false, status: 'Tracking…');

  Future<void> startReplay({int speedX = 10}) async {
    final gpx = await rootBundle.loadString('assets/demo_loop.gpx');
    await _begin(
      ReplaySource.fromGpx(gpx, speedX: speedX),
      replaying: true,
      status: 'Replaying the recorded loop at ${speedX}x',
    );
  }

  Future<void> startCaptureTest() async {
    final runner = state.currentFix?.point ?? state.origin ?? fallbackOrigin;
    final run = SimulatedRuns.capture(
      runner: runner,
      existing: [
        for (final t in state.territories)
          if (TerritoryEngine.fromWkt(t.wkt) case final g? when g.isNotEmpty) g,
      ],
    );
    await _begin(
      ReplaySource(run.points),
      replaying: true,
      status: run.description,
    );
  }

  Future<bool> startStealTest() async {
    final runner = state.currentFix?.point ?? state.origin ?? fallbackOrigin;
    final run = SimulatedRuns.steal(
      runner: runner,
      rivals: [
        for (final t in state.territories)
          if (t.ownerId != state.playerId)
            if (TerritoryEngine.fromWkt(t.wkt) case final g? when g.isNotEmpty)
              PlannedRival(ownerId: t.ownerId, ownerName: t.ownerName, geometry: g),
      ],
    );
    if (run == null) return false;
    await _begin(
      ReplaySource(run.points),
      replaying: true,
      status: run.description,
    );
    return true;
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
    _stepBase = null;
    _lastGainAltitude = null;
    _smoothedAltitude = 0;

    _gate.reset();

    state = state.copyWith(
      running: true,
      closed: false,
      track: const [],
      clearClaim: true,
      distanceM: 0,
      closureProgress: 0,
      claimedAreaM2: 0,
      stolenAreaM2: 0,
      stolenFromCount: 0,
      steps: 0,
      elevationGainM: 0,
      elevationSeries: const [],
      clearAltitude: true,
      startedAt: _startedAt,
      verified: true,
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
    if (!LocationSource.accept(fix)) return;

    final verdict = _gate.admit(fix);
    if (!verdict.accepted) return;

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

    final distanceM = verdict.creditsDistance && previousPoint != null
        ? state.distanceM + Projection.haversine(previousPoint, fix.point)
        : state.distanceM;

    final closed = LoopDetector.isClosed(track, travelledM: distanceM);

    final gpsAltitude = state.availability.barometer ? null : fix.altitudeM;

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
      closureProgress: LoopDetector.closureProgress(
        track,
        travelledM: distanceM,
      ),
      verified: _plausibility.verified,
      altitudeM: gpsAltitude,
      elevationSeries: elevationSeries,
      status: closed ? 'Loop closed — resolving claim' : state.status,
    );

    _territorySync?.follow(fix.point);

    if (closed) unawaited(_finish(track));
  }

  Future<void> _finish(List<LatLng> track) async {
    await _stopSources();
    unawaited(_haptics.loopClosed());

    final reference = _runOrigin ?? state.origin ?? fallbackOrigin;
    final claim = TerritoryEngine.buildTerritoryGeographic(track, reference);
    final repository = _repository;

    if (claim == null || repository == null) {
      state = state.copyWith(
        running: false,
        status: claim == null
            ? 'Loop closed, but no usable polygon'
            : 'Loop closed, but storage is not ready',
      );
      return;
    }

    final startedAt = _startedAt ?? DateTime.now();
    final preview = await repository.previewClaim(claim);

    state = state.copyWith(
      closed: true,
      running: false,
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
      ),
    );
  }

  Future<void> saveRun({String? title}) async {
    final pending = state.pendingRun;
    final repository = _repository;
    if (pending == null || repository == null) return;

    final claim = pending.claim;
    final outcome = claim == null
        ? null
        : await repository.commitClaim(
            claimGeographic: claim,
            reference: pending.reference,
            verified: pending.verified,
          );

    final saved = await repository.saveRun(
      id: const Uuid().v4(),
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

    unawaited(_publishSaved(saved));

    state = state.copyWith(
      clearClaim: true,
      clearPending: true,
      claimedAreaM2: outcome?.areaM2 ?? 0,
      stolenAreaM2: outcome?.stolenAreaM2 ?? 0,
      stolenFromCount: outcome?.stolenFromCount ?? 0,
      status: outcome == null ? 'Run saved' : 'Claimed',
    );
  }

  Future<void> _publishSaved(Run saved) async {
    try {
      final sync = await ref.read(syncServiceProvider.future);
      await sync.onRunSaved(saved);
    } catch (error) {
      debugPrint('ClaimTrek: could not publish the saved run — $error');
    }
  }

  void discardRun() {
    _gate.reset();
    state = state.copyWith(
      clearClaim: true,
      clearPending: true,
      closed: false,
      track: const [],
      distanceM: 0,
      closureProgress: 0,
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

  void _onExhausted() {
    if (!state.closed) _offerRunWithoutClaim();
  }

  Future<void> stop() async {
    await _stopSources();
    _offerRunWithoutClaim();
  }

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
    NotifierProvider<TrackingController, TrackingState>(TrackingController.new);
