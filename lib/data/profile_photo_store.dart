import 'dart:io';

import 'package:uuid/uuid.dart';

/// The profile picture's file on this device.
///
/// Copied out of the picker's cache into the app's own storage, because the cache is the OS's
/// to clear and a profile picture is meant to stay.
class ProfilePhotoStore {
  ProfilePhotoStore(this._directory, [this._uuid = const Uuid()]);

  final Future<Directory> Function() _directory;
  final Uuid _uuid;

  /// Keeps [sourcePath] as the new picture and deletes [previousPath], returning the new path.
  ///
  /// A fresh file name every time rather than overwriting one: the avatar is cached by path,
  /// and the same path with new bytes would keep showing the old face.
  Future<String> replace(String sourcePath, {String? previousPath}) async {
    final dir = await _directory();
    if (!await dir.exists()) await dir.create(recursive: true);
    final target = '${dir.path}${Platform.pathSeparator}${_uuid.v4()}.jpg';
    await File(sourcePath).copy(target);
    if (previousPath != null) await remove(previousPath);
    return target;
  }

  Future<void> remove(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone; the point was for it not to exist.
    }
  }
}
