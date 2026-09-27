import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_sensors.dart';
import '../location/location_access.dart';
import 'auth/auth_service.dart';
import 'auth/user_directory.dart';
import 'leaderboard_merge.dart';
import 'local/database.dart';
import 'model/models.dart';
import 'player_identity.dart';
import 'remote/firestore_mirror.dart';
import 'remote/overpass_client.dart';
import 'remote/territory_store.dart';
import 'sync_service.dart';
import 'territory_repository.dart';
import 'territory_sync.dart';
import 'trail_repository.dart';

final databaseProvider = Provider<ClaimTrekDatabase>((ref) {
  final db = ClaimTrekDatabase();
  ref.onDispose(db.close);
  return db;
});

final playerIdentityProvider = FutureProvider<PlayerIdentity>((ref) async {
  final identity = await PlayerIdentity.load();

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

final leaderboardProvider = StreamProvider<List<LeaderboardEntry>>((
  ref,
) async* {
  final repository = await ref.watch(territoryRepositoryProvider.future);
  final player = await ref.watch(playerIdentityProvider.future);
  final mirror = ref.watch(firestoreMirrorProvider);

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

final runsProvider = StreamProvider<List<Run>>((ref) async* {
  final repository = await ref.watch(territoryRepositoryProvider.future);
  yield* repository.watchRuns();
});

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

final sensorAvailabilityProvider = FutureProvider<SensorAvailability>((
  ref,
) async {
  try {
    return await SensorAvailability.probe();
  } catch (_) {
    return const SensorAvailability.none();
  }
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final userDirectoryProvider = Provider<UserDirectory>(
  (ref) => UserDirectory(FirebaseFirestore.instance),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

final firebaseReadyProvider = Provider<bool>((ref) => false);

final firestoreMirrorProvider = Provider<FirestoreMirror?>(
  (ref) => ref.watch(firebaseReadyProvider)
      ? FirestoreMirror(FirebaseFirestore.instance)
      : null,
);

final FutureProvider<TerritorySync> territorySyncProvider =
    FutureProvider<TerritorySync>((ref) async {
      final player = await ref.watch(playerIdentityProvider.future);
      final sync = TerritorySync(
        ref.watch(databaseProvider),
        ref.watch(firebaseReadyProvider)
            ? TerritoryStore(FirebaseFirestore.instance)
            : null,
        player,
        onOwnGroundChanged: () async {
          final service = await ref.read(syncServiceProvider.future);
          await service.republishStanding();
        },
      )..start();
      ref.onDispose(sync.dispose);
      return sync;
    });

final FutureProvider<SyncService> syncServiceProvider =
    FutureProvider<SyncService>((ref) async {
      return SyncService(
        await ref.watch(territoryRepositoryProvider.future),
        ref.watch(firestoreMirrorProvider),
        await ref.watch(playerIdentityProvider.future),
        territories: await ref.watch(territorySyncProvider.future),
      );
    });
