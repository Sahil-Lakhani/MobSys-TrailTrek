import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_sensors.dart';
import '../location/location_access.dart';
import 'local/database.dart';
import 'model/models.dart';
import 'player_identity.dart';
import 'remote/overpass_client.dart';
import 'territory_repository.dart';
import 'trail_repository.dart';

/// One database for the app's lifetime. Closed when the container is disposed so tests and
/// hot restarts do not leak connections.
final databaseProvider = Provider<ClaimTrekDatabase>((ref) {
  final db = ClaimTrekDatabase();
  ref.onDispose(db.close);
  return db;
});

final playerIdentityProvider = FutureProvider<PlayerIdentity>(
  (ref) => PlayerIdentity.load(),
);

final territoryRepositoryProvider = FutureProvider<TerritoryRepository>((
  ref,
) async {
  final player = await ref.watch(playerIdentityProvider.future);
  return TerritoryRepository(ref.watch(databaseProvider), player);
});

/// The ranked board, straight off the territory table.
///
/// A stream rather than a fetch: claiming ground has to move you up the table without
/// anyone pulling to refresh.
final leaderboardProvider = StreamProvider<List<LeaderboardEntry>>((ref) async* {
  final repository = await ref.watch(territoryRepositoryProvider.future);
  yield* repository.watchLeaderboard();
});

/// Every run recorded, newest first.
///
/// Includes runs that never closed a loop: they took no ground, but they happened.
final runsProvider = StreamProvider<List<Run>>((ref) async* {
  final repository = await ref.watch(territoryRepositoryProvider.future);
  yield* repository.watchRuns();
});

/// Timeouts are generous: Overpass is a free public instance under load, and a slow answer is
/// still far better than a failed one when the alternative is an empty treks tab.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 40),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final trailRepositoryProvider = Provider<TrailRepository>(
  (ref) => TrailRepository(
    ref.watch(databaseProvider),
    OverpassClient(ref.watch(dioProvider)),
  ),
);

final locationAccessGateProvider = Provider<LocationAccessGate>(
  (ref) => const LocationAccessGate(),
);

/// Probed once per launch. Every sensor-backed feature reads this before rendering, so that a
/// device without the hardware simply never shows the control.
final sensorAvailabilityProvider = FutureProvider<SensorAvailability>((
  ref,
) async {
  try {
    return await SensorAvailability.probe();
  } catch (_) {
    // A platform with no sensor plugins at all (a test host, desktop) claims nothing.
    return const SensorAvailability.none();
  }
});
