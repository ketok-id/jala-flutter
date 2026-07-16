part of 'jala_event.dart';

/// Emitted when a WebSocket connection attempt begins.
///
/// `JalaStore` materializes this into a new `WsConnectionEntry` in
/// `WsConnectionStatus.connecting`.
class WsConnectEvent extends JalaEvent {
  /// Creates a WS connect event. [connectionId] correlates every event
  /// (and the resulting `WsConnectionEntry`) for this connection — it is
  /// carried as [JalaEvent.callId] under the hood so `WsConnectEvent` can
  /// extend the shared sealed [JalaEvent] base without widening it.
  const WsConnectEvent({
    required String connectionId,
    required super.timestamp,
    required this.uri,
  }) : super(callId: connectionId);

  /// Convenience alias for [callId] in WS contexts.
  String get connectionId => callId;

  /// The full WebSocket URI (`ws://` or `wss://`).
  final Uri uri;
}

/// Emitted when a WebSocket connection is confirmed open — the handshake
/// completed successfully (`WebSocketChannel.ready` resolved without error).
///
/// `JalaStore` promotes the matching `WsConnectionEntry.status` from
/// `WsConnectionStatus.connecting` to `WsConnectionStatus.open`. This is a
/// courtesy for bindings (like `jala_websocket`) that can observe the
/// handshake explicitly; D1's original fallback — promoting on first frame,
/// for bindings that can't observe the handshake — still applies and keeps
/// working (see `JalaStore._onWsFrame`). Emitting this event for an already
/// non-`connecting` connection (e.g. one that already closed or errored) is
/// a no-op — see `JalaStore._onWsOpen`.
class WsOpenEvent extends JalaEvent {
  /// Creates a WS open event for [connectionId].
  const WsOpenEvent({required String connectionId, required super.timestamp})
    : super(callId: connectionId);

  /// Convenience alias for [callId] in WS contexts.
  String get connectionId => callId;
}

/// Emitted for every frame sent or received on a WebSocket connection.
class WsFrameEvent extends JalaEvent {
  /// Creates a WS frame event for [connectionId].
  const WsFrameEvent({
    required String connectionId,
    required super.timestamp,
    required this.frame,
  }) : super(callId: connectionId);

  /// Convenience alias for [callId] in WS contexts.
  String get connectionId => callId;

  /// The captured frame.
  final WsFrame frame;
}

/// Emitted when a WebSocket connection closes (normally or otherwise, but
/// short of a transport error — see [WsErrorEvent]).
class WsCloseEvent extends JalaEvent {
  /// Creates a WS close event for [connectionId].
  const WsCloseEvent({
    required String connectionId,
    required super.timestamp,
    this.code,
    this.reason,
  }) : super(callId: connectionId);

  /// Convenience alias for [callId] in WS contexts.
  String get connectionId => callId;

  /// The close code, if reported.
  final int? code;

  /// The close reason, if reported.
  final String? reason;
}

/// Emitted when a WebSocket connection fails at the transport level.
class WsErrorEvent extends JalaEvent {
  /// Creates a WS error event for [connectionId].
  const WsErrorEvent({
    required String connectionId,
    required super.timestamp,
    required this.errorMessage,
  }) : super(callId: connectionId);

  /// Convenience alias for [callId] in WS contexts.
  String get connectionId => callId;

  /// Human-readable error description.
  final String errorMessage;
}
