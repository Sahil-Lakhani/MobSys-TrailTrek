import 'dart:io';

import 'package:uuid/uuid.dart';

import '../geo/lat_lng.dart';
import 'local/database.dart';

/// A photo taken during a run that has not been saved yet.
///
/// The image file already sits in the app's own storage — the camera's output is a cache file
/// the OS may clear — but nothing is in the database until the run is saved. Discarding the run
/// deletes the file, so a discarded run leaves no trace here either.
class PendingPhoto {
  final String filePath;
  final DateTime takenAt;

  /// Where the runner was. Null if the run had no fix yet.
  final LatLng? point;

  /// How far into the run it was taken.
  final double distanceM;

  const PendingPhoto({
    required this.filePath,
    required this.takenAt,
    required this.point,
    required this.distanceM,
  });
}

/// Run photos: the files on disk and the rows that say which run they belong to.
///
/// The UI talks to this; it never touches the DAO or the file system directly.
class PhotoRepository {
  /// [photosDirectory] is where images are kept. A function rather than a path because the
  /// real one comes from `path_provider` asynchronously, and tests hand in a temp directory.
  PhotoRepository(this._db, this._photosDirectory, [this._uuid = const Uuid()]);

  final ClaimTrekDatabase _db;
  final Future<Directory> Function() _photosDirectory;
  final Uuid _uuid;

  RunPhotoDao get _photos => _db.runPhotoDao;

  Stream<List<RunPhoto>> watchForRun(String runId) =>
      _photos.watchForRun(runId);

  Stream<List<RunPhoto>> watchAll() => _photos.watchAll();

  /// Moves a freshly taken photo out of the camera's cache into the app's own storage, and
  /// returns where it now lives.
  Future<String> keep(String sourcePath) async {
    final dir = await _photosDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    final target = '${dir.path}${Platform.pathSeparator}${_uuid.v4()}.jpg';
    await File(sourcePath).copy(target);
    // The camera's copy is no longer needed. Failing to remove it costs cache space, not a
    // photo, so it does not fail the capture.
    try {
      await File(sourcePath).delete();
    } on FileSystemException {
      // Already gone, or not ours to delete.
    }
    return target;
  }

  /// Files the photos of a run that has just been saved.
  Future<void> attachToRun(String runId, List<PendingPhoto> photos) async {
    if (photos.isEmpty) return;
    await _photos.insertAll([
      for (final photo in photos)
        RunPhoto(
          id: _uuid.v4(),
          runId: runId,
          filePath: photo.filePath,
          takenAt: photo.takenAt.millisecondsSinceEpoch,
          lat: photo.point?.latitude,
          lng: photo.point?.longitude,
          distanceM: photo.distanceM,
        ),
    ]);
  }

  /// Deletes the files of a run that was discarded. Nothing was written to the database.
  Future<void> discard(List<PendingPhoto> photos) async {
    for (final photo in photos) {
      try {
        await File(photo.filePath).delete();
      } on FileSystemException {
        // Already gone. The point was for it not to exist, and it does not.
      }
    }
  }
}
