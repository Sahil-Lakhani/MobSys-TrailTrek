import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../device/device_sensors.dart';
import '../location/location_access.dart';
import 'auth/auth_service.dart';
import 'auth/user_directory.dart';
import 'leaderboard_merge.dart';
import 'local/database.dart';
import 'model/models.dart';
import 'photo_repository.dart';
import 'player_identity.dart';
import 'remote/firestore_mirror.dart';
import 'remote/overpass_client.dart';
import 'sync_service.dart';
import 'territory_repository.dart';
import 'trail_repository.dart';

/// One database for the app's lifetime. Closed when the container is disposed so tests and
/// hot restarts do not leak connections.
final databaseProvider = Provider<ClaimTrekDatabase>((ref) {
  final db = ClaimTrekDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Who the game files claims under.
///
/// Watches the signed-in user, so signing in or out rebuilds the repository and every claim
/// from that moment is filed under the right owner.
final playerIdentityProvider = FutureProvider<PlayerIdentity>((ref) async {
  final identity = await PlayerIdentity.load();

  // Reading auth at all requires Firebase to have started; on a local-only build it has not.
  if (ref.watch(firebaseReadyProvider)) {
    final user = ref.watch(authStateProvider).value;
    if (user != null) {
      identity.bindTo(
        uid: user.uid,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
    }
  }
  return identity;
});

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
  final player = await ref.watch(playerIdentityProvider.future);
  final mirror = ref.watch(firestoreMirrorProvider);

  // Signed out there is no second source, and no reason to open a listener on one.
  if (mirror == null || !player.isSignedIn) {
    yield* repository.watchLeaderboard();
    return;
  }

  yield* _mergedBoard(
    local: repository.watchLeaderboard(),
    remote: mirror.watchLeaderboard(myId: player.id),
    myId: player.id,
  );
});

/// Emits a fresh ranking whenever either source moves.
///
/// A failure on the remote side is swallowed rather than forwarded: losing the network should
/// cost you the other players, not your own board.
Stream<List<LeaderboardEntry>> _mergedBoard({
  required Stream<List<LeaderboardEntry>> local,
  required Stream<List<LeaderboardEntry>> remote,
  required String myId,
}) {
  var latestLocal = const <LeaderboardEntry>[];
  var latestRemote = const <LeaderboardEntry>[];
  late StreamController<List<LeaderboardEntry>> controller;
  final subscriptions = <StreamSubscription<List<LeaderboardEntry>>>[];

  void emit() => controller.add(
    mergeLeaderboards(local: latestLocal, remote: latestRemote, myId: myId),
  );

  controller = StreamController<List<LeaderboardEntry>>(
    onListen: () {
      subscriptions.add(
        local.listen((rows) {
          latestLocal = rows;
          emit();
        }, onError: controller.addError),
      );
      subscriptions.add(
        remote.listen(
          (rows) {
            latestRemote = rows;
            emit();
          },
          onError: (Object error) {
            debugPrint('ClaimTrek: leaderboard is local-only — $error');
          },
        ),
      );
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );

  return controller.stream;
}

/// Every run recorded, newest first.
///
/// Includes runs that never closed a loop: they took no ground, but they happened.
final runsProvider = StreamProvider<List<Run>>((ref) async* {
  final repository = await ref.watch(territoryRepositoryProvider.future);
  yield* repository.watchRuns();
});

/// Photos taken during runs. Kept under the app's documents directory, which the OS does not
/// clear and other apps cannot read.
final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => PhotoRepository(
    ref.watch(databaseProvider),
    () async => Directory(
      '${(await getApplicationDocumentsDirectory()).path}'
      '${Platform.pathSeparator}run_photos',
    ),
  ),
);

/// One run's photos, in the order they were taken.
final runPhotosProvider = StreamProvider.family<List<RunPhoto>, String>(
  (ref, runId) => ref.watch(photoRepositoryProvider).watchForRun(runId),
);

/// Every run photo, newest first.
final allPhotosProvider = StreamProvider<List<RunPhoto>>(
  (ref) => ref.watch(photoRepositoryProvider).watchAll(),
);

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


// ------------------------------------------------------------------------ auth

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final userDirectoryProvider = Provider<UserDirectory>(
  (ref) => UserDirectory(FirebaseFirestore.instance),
);

/// Who is signed in, as it changes.
///
/// A stream rather than a one-off read so a sign-out anywhere — including a token expiring or
/// the account being removed from the device — reaches the whole app at once.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// True once Firebase is up. False means the app is running local-only, which is a legitimate
/// state on a build whose `firebase_options.dart` has not been generated yet.
///
/// Overridden at the root in `main`, which is the only place that knows. Defaults to false so
/// a test or a tool that builds a widget without going through `main` gets the local-only
/// path rather than an exception — the same answer a device with no Firebase would give.
final firebaseReadyProvider = Provider<bool>((ref) => false);

/// Null on a build where Firebase never started — every caller treats that as "local only".
final firestoreMirrorProvider = Provider<FirestoreMirror?>(
  (ref) => ref.watch(firebaseReadyProvider)
      ? FirestoreMirror(FirebaseFirestore.instance)
      : null,
);

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  return SyncService(
    await ref.watch(territoryRepositoryProvider.future),
    ref.watch(firestoreMirrorProvider),
    await ref.watch(playerIdentityProvider.future),
  );
});
