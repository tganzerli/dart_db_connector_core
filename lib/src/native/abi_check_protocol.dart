/// The ABI-compatibility check, shared by every driver package.
///
/// Each driver ships its own native library with its own independent
/// MAJOR/MINOR pair, and each one validated it with a near-identical copy of
/// this function — four files differing only in a symbol name and the text of
/// the messages. The *policy* is what the contract owns; the *numbers* stay
/// with the driver.
///
/// Policy:
///
///   - MAJOR mismatch                 -> throw StateError (fatal)
///   - linked MINOR >= expected MINOR -> OK (forward-compatible)
///   - linked MINOR <  expected MINOR -> warn on stderr (non-blocking)
///
/// A change to the
/// packed-version encoding here is a change to every driver's ABI contract at
/// once, and needs a decision record.
library;

import 'dart:ffi' as ffi;
import 'dart:io' show stderr;

typedef _AbiVersionNative = ffi.Int64 Function();
typedef _AbiVersionDart = int Function();

const int _kAbiMajorShift = 32;
const int _k32BitMask = 0xFFFFFFFF;

/// Reads the packed ABI version from [lib] via [symbol] and compares it
/// against the expected pair.
///
/// [libraryLabel] names the shared library in the messages (e.g.
/// `libnative_mongo`), [constantsHint] points at the Dart constants to bump,
/// and [buildHint] at the command that rebuilds the library. Returns the
/// linked library's `(major, minor)`.
({int major, int minor}) assertNativeAbiCompatible(
  ffi.DynamicLibrary lib, {
  required String symbol,
  required int expectedMajor,
  required int expectedMinor,
  required String libraryLabel,
  required String constantsHint,
  required String buildHint,
}) {
  final fn = lib.lookupFunction<_AbiVersionNative, _AbiVersionDart>(symbol);
  final packed = fn();
  final major = (packed >> _kAbiMajorShift) & _k32BitMask;
  final minor = packed & _k32BitMask;

  if (major != expectedMajor) {
    throw StateError(
      'ABI mismatch: $libraryLabel reports MAJOR=$major MINOR=$minor, but the '
      'Dart package expects MAJOR=$expectedMajor MINOR=$expectedMinor. '
      'MAJOR mismatch is FATAL — rebuild the native library ($buildHint) or '
      'update the Dart package ($constantsHint).',
    );
  }

  if (minor < expectedMinor) {
    stderr.writeln(
      '[dart_db_connector] WARNING: linked $libraryLabel reports MINOR=$minor '
      'but the Dart package expects MINOR>=$expectedMinor. Some features may '
      'be unavailable; consider rebuilding ($buildHint).',
    );
  }

  return (major: major, minor: minor);
}
