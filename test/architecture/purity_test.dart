import 'dart:io';

import 'package:test/test.dart';

/// `lib/geo/` and `lib/sensor/` carry the algorithms this app lives or dies by, and they are
/// deliberately free of any framework dependency. That is what lets their suites run in
/// milliseconds on a plain Dart VM with no emulator, no device and no Flutter binding.
///
/// Stating the rule in the docs is not enough — discipline is exactly what fails. Here it is
/// mechanical: add the wrong import and the build goes red.
void main() {
  const pureDirectories = ['lib/geo', 'lib/sensor'];
  const forbidden = ['package:flutter/', 'dart:ui', 'package:flutter_test/'];

  for (final directory in pureDirectories) {
    test('$directory imports no framework code', () {
      final dir = Directory(directory);
      expect(
        dir.existsSync(),
        isTrue,
        reason: '$directory is missing — the guard would silently pass',
      );

      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      expect(
        dartFiles,
        isNotEmpty,
        reason: '$directory has no Dart files — the guard would silently pass',
      );

      final violations = <String>[];
      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!line.trimLeft().startsWith('import ') &&
              !line.trimLeft().startsWith('export ')) {
            continue;
          }
          for (final banned in forbidden) {
            if (line.contains(banned)) {
              violations.add('${file.path}:${i + 1}: ${line.trim()}');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Framework imports found in a pure module. Move the framework-facing code '
            'into lib/ui or lib/location instead:\n${violations.join('\n')}',
      );
    });
  }
}
