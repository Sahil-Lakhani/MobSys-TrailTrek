import '../local/database.dart';
import '../sync_service.dart';
import '../territory_repository.dart';
import 'run_photo_store.dart';

class RunPhotos {
  RunPhotos(this._store, this._repository, this._sync);

  final RunPhotoStore _store;
  final TerritoryRepository _repository;
  final SyncService _sync;

  Future<Run?> attach(Run run, String sourcePath) async {
    final path = await _store.save(runId: run.id, sourcePath: sourcePath);
    final updated = await _repository.setRunPhoto(run.id, path);
    if (updated != null) await _sync.onRunPhotoChanged(updated);
    return updated;
  }

  Future<Run?> remove(Run run) async {
    await _store.delete(run.photoPath);
    final updated = await _repository.setRunPhoto(run.id, null);
    if (updated != null) await _sync.onRunPhotoChanged(updated);
    return updated;
  }
}
