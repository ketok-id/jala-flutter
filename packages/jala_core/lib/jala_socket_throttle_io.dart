/// `dart:io`-only entry point for socket-level throttling.
///
/// A second public library rather than part of the `jala_core` barrel,
/// because its types (`Socket`, `ConnectionTask`) cannot be named on web.
/// The main barrel exports a conditional `JalaSocketThrottle` whose web stub
/// reports `isSupported == false`; anything needing the real typed factory —
/// `package:jala`'s installer, and tests — imports this instead.
///
/// Importing this from web code is a compile error, by design.
library;

export 'src/throttle/jala_socket_throttle_io.dart';
