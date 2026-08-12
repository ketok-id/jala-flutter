/// Socket-level throttling, where the platform has `dart:io`.
///
/// `jala_core` is otherwise `dart:io`-free as well as Flutter-free, so this
/// follows the conditional-import pattern already used for file-backed mock
/// persistence in `package:jala`. Web resolves to the stub, keeps
/// `isSupported == false`, and stays on the adapter-level throttle path.
library;

export 'jala_socket_throttle_stub.dart'
    if (dart.library.io) 'jala_socket_throttle_io.dart';
