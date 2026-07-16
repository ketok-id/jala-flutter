/// `web_socket_channel` adapter for Jala, the in-app Flutter network
/// inspector.
///
/// Wraps any `WebSocketChannel` to capture its connection lifecycle
/// (connect/open/close/error) and every frame sent or received into
/// `JalaBinding.instance`. See [JalaWebSocketChannel.wrap] for the
/// recommended way to wire a `WebSocketChannel` into Jala.
library;

export 'src/jala_web_socket_channel.dart';
