import 'dart:io';

import 'package:claimtrek/data/local/database.dart';
import 'package:claimtrek/data/photo_repository.dart';
import 'package:claimtrek/geo/lat_lng.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ClaimTrekDatabase db;
  late Directory temp;
  late Directory photosDir;
  late PhotoRepository repository;

  setUp(() async {
    db = ClaimTrekDatabase.forTesting(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('claimtrek_photos_');
    photosDir = Directory('${temp.path}${Platform.pathSeparator}run_photos');
    repository = PhotoRepository(db, () async => photosDir);
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  /// Stands in for the camera's output: a file in a cache directory.
  Future<String> cameraShot(String name) async {
    final file = File('${temp.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes([1, 2, 3, name.length]);
    return file.path;
  }

  PendingPhoto pending(String path, int minute, {double distanceM = 0}) =>
      PendingPhoto(
        filePath: path,
        takenAt: DateTime(2026, 9, 25, 8, minute),
        point: const LatLng(50.7217, 10.4483),
        distanceM: distanceM,
      );

  test('a kept photo moves out of the camera cache into app storage', () async {
    final shot = await cameraShot('cache.jpg');

    final kept = await repository.keep(shot);

    expect(kept, startsWith(photosDir.path));
    expect(await File(kept).readAsBytes(), [1, 2, 3, 9]);
    expect(await File(shot).exists(), isFalse, reason: 'the cache copy is cleaned up');
  });

  test('attaching files the photos against the run, in the order taken', () async {
    final a = await repository.keep(await cameraShot('a.jpg'));
    final b = await repository.keep(await cameraShot('b.jpg'));

    await repository.attachToRun('run-1', [
      pending(b, 20, distanceM: 900),
      pending(a, 5, distanceM: 250),
    ]);

    final rows = await repository.watchForRun('run-1').first;
    expect(rows.map((r) => r.filePath), [a, b], reason: 'oldest first within a run');
    expect(rows.first.distanceM, 250);
    expect(rows.first.lat, closeTo(50.7217, 1e-9));

    expect(await repository.watchForRun('run-2').first, isEmpty);
  });

  test('the gallery lists every run\'s photos, newest first', () async {
    final a = await repository.keep(await cameraShot('a.jpg'));
    final b = await repository.keep(await cameraShot('b.jpg'));
    await repository.attachToRun('run-1', [pending(a, 5)]);
    await repository.attachToRun('run-2', [pending(b, 30)]);

    final all = await repository.watchAll().first;
    expect(all.map((r) => r.runId), ['run-2', 'run-1']);
  });

  test('discarding deletes the files and writes nothing', () async {
    final a = await repository.keep(await cameraShot('a.jpg'));

    await repository.discard([pending(a, 5)]);

    expect(await File(a).exists(), isFalse);
    expect(await repository.watchAll().first, isEmpty);
  });

  test('discarding a photo that is already gone does not throw', () async {
    await repository.discard([pending('${temp.path}/never-existed.jpg', 5)]);
  });
}
