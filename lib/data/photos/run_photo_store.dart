import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RunPhotoStore {
  RunPhotoStore({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  static const String folder = 'ClaimTrek';

  final Future<Directory> Function() _baseDirectory;

  Future<Directory> _folder() async {
    final base = await _baseDirectory();
    final dir = Directory(p.join(base.path, folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> save({
    required String runId,
    required String sourcePath,
  }) async {
    final dir = await _folder();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final name = 'run_${runId}_$stamp${p.extension(sourcePath).toLowerCase()}';
    await File(sourcePath).copy(p.join(dir.path, name));
    await _removeOthers(dir, runId, keep: name);
    return '$folder/$name';
  }

  Future<File?> resolve(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final base = await _baseDirectory();
    final file = File(p.join(base.path, relativePath));
    return await file.exists() ? file : null;
  }

  Future<void> delete(String? relativePath) async {
    final file = await resolve(relativePath);
    if (file != null) await file.delete();
  }

  Future<void> _removeOthers(
    Directory dir,
    String runId, {
    required String keep,
  }) async {
    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      if (entity is File && name.startsWith('run_${runId}_') && name != keep) {
        await entity.delete();
      }
    }
  }
}
