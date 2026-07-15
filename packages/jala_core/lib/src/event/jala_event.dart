import '../model/captured_body.dart';

/// Base type for everything flowing through [JalaEventBus].
///
/// Every event carries a `callId` used by `JalaStore` to correlate
/// request/response/error/cancel events for the same network call into a
/// single `NetworkCallEntry`.
sealed class JalaEvent {
  const JalaEvent({required this.callId, required this.timestamp});

  /// Correlation id shared by all events belonging to the same call. This
  /// is also the resulting `NetworkCallEntry.id`.
  final String callId;

  /// When this event occurred.
  final DateTime timestamp;
}

/// Emitted when a request is about to be sent.
class NetworkRequestEvent extends JalaEvent {
  const NetworkRequestEvent({
    required super.callId,
    required super.timestamp,
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
    required this.client,
    this.size,
    this.replayOf,
  });

  /// HTTP method, uppercased.
  final String method;

  /// Full request URI.
  final Uri uri;

  /// Request headers, already redacted.
  final Map<String, String> headers;

  /// Captured request body.
  final CapturedBody body;

  /// Best-effort request body size in bytes.
  final int? size;

  /// Identifies which client/library captured this call, e.g. `'dio'`.
  final String client;

  /// The id of the original call this request replays, if any.
  ///
  /// SPEC-NOTE: the spec's event bullet list for `NetworkRequestEvent` only
  /// names `method, uri, headers, body, size, client`, but
  /// `NetworkCallEntry.replayOf` has to originate somewhere — the request
  /// event is the natural place for a replaying client (e.g. `jala_dio`)
  /// to declare it, so it is included here as an optional field.
  final String? replayOf;
}

/// Emitted when a response is received for a call.
class NetworkResponseEvent extends JalaEvent {
  const NetworkResponseEvent({
    required super.callId,
    required super.timestamp,
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.duration,
    this.statusMessage,
    this.size,
  });

  /// HTTP status code.
  final int statusCode;

  /// HTTP status message, if known.
  final String? statusMessage;

  /// Response headers, already redacted.
  final Map<String, String> headers;

  /// Captured response body.
  final CapturedBody body;

  /// Best-effort response body size in bytes.
  final int? size;

  /// Wall-clock duration of the call.
  final Duration duration;
}

/// Emitted when a call fails at the transport/client level (as opposed to
/// merely receiving a non-2xx response).
class NetworkErrorEvent extends JalaEvent {
  const NetworkErrorEvent({
    required super.callId,
    required super.timestamp,
    required this.errorMessage,
    this.statusCode,
    this.headers,
    this.body,
    this.duration,
  });

  /// Human-readable error description.
  final String errorMessage;

  /// HTTP status code, if a response was received before the error.
  final int? statusCode;

  /// Response headers, if any were received.
  final Map<String, String>? headers;

  /// Captured response body, if any was received.
  final CapturedBody? body;

  /// Wall-clock duration until the error, if known.
  final Duration? duration;
}

/// Emitted when a call is cancelled before completion.
class NetworkCancelEvent extends JalaEvent {
  const NetworkCancelEvent({required super.callId, required super.timestamp});
}
