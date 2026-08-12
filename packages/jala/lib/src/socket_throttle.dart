/// Socket-level throttling installation, where the platform has `dart:io`.
library;

export 'socket_throttle_stub.dart'
    if (dart.library.io) 'socket_throttle_io.dart';
