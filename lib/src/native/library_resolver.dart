/// Cross-platform resolver for a driver's native shared library.
///
/// Walks a small list of canonical candidate paths so the consumer does not
/// need to know where the binary actually sits. The first existing file wins.
///
/// This is the mechanism half of what used to be `native_lib_loader.dart` in
/// the monolith: that file knew all four drivers by name, which made it the
/// second place (after the contract) that had to change every time a driver
/// was added. Here the driver-specific parts — filenames, environment
/// variable, package name, ABI check — are parameters, and each driver
/// package supplies its own.
///
/// Search order, in priority:
///
/// 1. **Explicit override** — the `overridePath` argument, then the
///    [envOverride] environment variable (absolute path). Useful for
///    debugging, CI matrix runs, or pinning a specific build during dev.
/// 2. **Near the executing binary** — two variants checked in order:
///    - `dirname(Platform.resolvedExecutable)/<fileName>` (flat: exe and
///      `.so` side by side; the simplest AOT layout).
///    - `dirname(Platform.resolvedExecutable)/lib/_native/<os>-<arch>/<fileName>`
///      (the pub-cache mirror: if a consumer `COPY`s the `lib/` subtree from
///      `~/.pub-cache/...` next to the exe, the `.so` lives here). This is the
///      layout pre-built releases produce. Headless Docker deployments target
///      either form.
/// 3. **Package URI** `package:<packageName>/_native/<os>-<arch>/<fileName>`
///    resolved via `Isolate.resolvePackageUriSync`. Reserved for releases that
///    ship pre-built binaries via CI. Works in JIT (`dart run`, `dart test`);
///    silently no-ops in AOT (where `package_config.json` is unavailable).
/// 4. **`/usr/local/lib/<fileName>`** — system-wide install on Linux/macOS for
///    ops teams that prefer global libraries.
/// 5. **Repo dev paths** (current working directory and CMake build
///    locations), so the local build cycle keeps working. A driver package
///    with its own `native/` tree passes its build directories in
///    [extraDevPaths].
/// 6. If nothing matches: `StateError` with the failed-candidate list and the
///    build command from [buildHint].
library;

import 'dart:ffi' as ffi;
import 'dart:io' show File, Platform;
import 'dart:isolate';

import 'package:meta/meta.dart';

/// Per-OS native library filenames for one driver's shared library.
typedef LibNames = ({String macOS, String linux, String windows});

/// Opens the native library for one driver.
///
/// [names] gives the filename per OS, [envOverride] the absolute-path escape
/// hatch, and [packageName] the package whose `_native/` subtree holds the
/// shipped binary. [extraDevPaths] are checked last and are meant for the
/// in-repo CMake build directories; each is used verbatim as a directory
/// prefix. [buildHint] is the command shown in the failure message.
ffi.DynamicLibrary openDriverLibrary({
  required LibNames names,
  required String envOverride,
  required String packageName,
  String? overridePath,
  List<String> extraDevPaths = const [],
  String buildHint = 'cmake -S native -B native/build && '
      'cmake --build native/build',
}) {
  // Path #1 — explicit override via argument (also accepted from env
  // when no argument is supplied).
  final pathFromArg = overridePath;
  if (pathFromArg != null) {
    return ffi.DynamicLibrary.open(pathFromArg);
  }
  final pathFromEnv = Platform.environment[envOverride];
  if (pathFromEnv != null && pathFromEnv.isNotEmpty) {
    return ffi.DynamicLibrary.open(pathFromEnv);
  }

  final fileName = libraryFileName(names);
  final candidates = <String>[];

  // Path #2 — near the executing binary.
  final platformId = _platformIdentifier();
  final exeDir = _executableDirectory();
  if (exeDir != null) {
    candidates.add('$exeDir/$fileName');
    candidates.add('$exeDir/lib/_native/$platformId/$fileName');
  }

  // Path #3 — package URI for the bundled native asset.
  final pkgPath = _resolvePackageNativeLibPath(packageName, platformId, fileName);
  if (pkgPath != null) {
    candidates.add(pkgPath);
  }

  // Path #4 — system-wide install (Linux/macOS).
  if (!Platform.isWindows) {
    candidates.add('/usr/local/lib/$fileName');
  }

  // Path #5 — dev paths for the local CMake build cycle.
  candidates.add(fileName);
  for (final dir in extraDevPaths) {
    candidates.add('$dir/$fileName');
  }

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return ffi.DynamicLibrary.open(candidate);
    }
  }

  throw StateError(
    'Native library "$fileName" not found in any of:\n  '
    '${candidates.join("\n  ")}\n\n'
    'Two ways to resolve, in priority order:\n'
    ' (a) Set $envOverride=/abs/path/to/$fileName, or\n'
    ' (b) Build the library locally:\n'
    '       $buildHint\n\n'
    'Releases ship pre-built binaries at '
    'lib/_native/$platformId/$fileName so this resolver finds them '
    'automatically without any user intervention.',
  );
}

/// Picks the filename for the running OS.
String libraryFileName(LibNames names) {
  if (Platform.isMacOS) return names.macOS;
  if (Platform.isLinux) return names.linux;
  if (Platform.isWindows) return names.windows;
  throw UnsupportedError(
    'Unsupported OS: ${Platform.operatingSystem}. '
    'Supported: macOS, Linux, Windows.',
  );
}

/// Returns the directory of the executing Dart process when that matches a
/// real filesystem location. Returns null when the executable path is not
/// informative (e.g. inside the Dart VM running through `dart run` where it
/// points to `dart` itself).
String? _executableDirectory() {
  try {
    final exe = Platform.resolvedExecutable;
    if (exe.isEmpty) return null;
    final lastSep = exe.lastIndexOf(Platform.pathSeparator);
    if (lastSep <= 0) return null;
    return exe.substring(0, lastSep);
  } catch (_) {
    return null;
  }
}

/// Resolves `package:<packageName>/_native/<os>-<arch>/<fileName>` to a real
/// file path via the current isolate's package config. Returns null when the
/// package config is unavailable (AOT mode) or when the URI cannot be
/// resolved (the file might not exist yet — the resolver checks
/// `File.existsSync` afterwards).
String? _resolvePackageNativeLibPath(
  String packageName,
  String platformId,
  String fileName,
) {
  try {
    final uri = Uri.parse(
      'package:$packageName/_native/$platformId/$fileName',
    );
    final resolved = Isolate.resolvePackageUriSync(uri);
    return resolved?.toFilePath();
  } catch (_) {
    return null;
  }
}

/// Identifies the running platform with the convention used inside
/// `lib/_native/<id>/`. Examples: `macos-arm64`, `linux-x64`, `windows-x64`.
@visibleForTesting
String detectPlatformId() => _platformIdentifier();

String _platformIdentifier() {
  final os = Platform.isMacOS
      ? 'macos'
      : Platform.isLinux
          ? 'linux'
          : Platform.isWindows
              ? 'windows'
              : Platform.operatingSystem;
  final arch = _detectArch();
  return '$os-$arch';
}

/// Best-effort architecture detection. Reads `Platform.version` which embeds
/// the host architecture suffix (`... on "<os>_<arch>"`). Returns `'unknown'`
/// when the parse fails — the caller should treat path #3 as a soft miss in
/// that case.
String _detectArch() {
  try {
    final version = Platform.version;
    // version example: '3.11.6 (stable) (...) on "macos_arm64"'
    final match = RegExp(r'on "[^_"]+_([^"]+)"').firstMatch(version);
    if (match != null) {
      final raw = match.group(1)!;
      // Normalise to the conventional names used by the
      // `lib/_native/<os>-<arch>/` layout.
      return switch (raw) {
        'arm64' => 'arm64',
        'x64' || 'x86_64' || 'amd64' => 'x64',
        'ia32' || 'x86' => 'ia32',
        _ => raw,
      };
    }
  } catch (_) {
    // fall through
  }
  return 'unknown';
}
