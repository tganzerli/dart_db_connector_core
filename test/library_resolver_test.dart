/// Unit tests for the shared native library resolver.
///
/// The platform identifier must match the `lib/_native/<os>-<arch>/`
/// convention that pre-built binary releases populate and that path #3 of the
/// resolver looks under. It moved here from the monolith on 2026-09-08, with
/// the mechanism it exercises.
library;

import 'dart:io';

import 'package:dart_db_connector_core/dart_db_connector_core.dart';
import 'package:test/test.dart';

void main() {
  group('detectPlatformId', () {
    test('returns a non-empty <os>-<arch> string', () {
      final id = detectPlatformId();
      expect(id, isNotEmpty);
      expect(id.contains('-'), isTrue,
          reason: 'expected <os>-<arch> shape; got "$id"');
      final parts = id.split('-');
      expect(parts.length, 2, reason: 'expected exactly 2 parts in "$id"');
      expect(parts[0], anyOf('macos', 'linux', 'windows', isNot(equals(''))));
      expect(parts[1], isNotEmpty,
          reason: 'architecture must be detectable; got "${parts[1]}"');
    });

    test('matches the current OS', () {
      final id = detectPlatformId();
      if (Platform.isMacOS) {
        expect(id, startsWith('macos-'));
      } else if (Platform.isLinux) {
        expect(id, startsWith('linux-'));
      } else if (Platform.isWindows) {
        expect(id, startsWith('windows-'));
      }
    });
  });

  group('libraryFileName', () {
    test('picks the filename of the running OS', () {
      const names = (
        macOS: 'libx.dylib',
        linux: 'libx.so',
        windows: 'x.dll',
      );
      final name = libraryFileName(names);
      if (Platform.isMacOS) expect(name, 'libx.dylib');
      if (Platform.isLinux) expect(name, 'libx.so');
      if (Platform.isWindows) expect(name, 'x.dll');
    });
  });

  group('openDriverLibrary', () {
    test('reports every candidate it tried when nothing resolves', () {
      const names = (
        macOS: 'libnope.dylib',
        linux: 'libnope.so',
        windows: 'nope.dll',
      );
      expect(
        () => openDriverLibrary(
          names: names,
          envOverride: 'DART_DB_CONNECTOR_NO_SUCH_ENV_VAR',
          packageName: 'no_such_package',
          extraDevPaths: const ['some/build/dir'],
          buildHint: 'build it like this',
        ),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('some/build/dir'))
              .having((e) => e.message, 'message', contains('build it like this'))
              .having((e) => e.message, 'message',
                  contains('DART_DB_CONNECTOR_NO_SUCH_ENV_VAR')),
        ),
      );
    });
  });
}
