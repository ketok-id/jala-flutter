import '../event/jala_event.dart';
import 'captured_body.dart';
import 'jala_call_status.dart';

/// Sentinel used by [NetworkCallEntry.copyWith] so nullable fields can be
/// distinguished from "leave unchanged" (omitted) vs. "explicitly set to
/// null".
const Object _unset = Object();

/// An immutable, point-in-time snapshot of one captured network call.
///
/// Instances are materialized and replaced (never mutated) by
/// `JalaStore` as request/response/error/cancel events for the same
/// `callId` arrive — see `src/store/jala_store.dart`.
class NetworkCallEntry {
  /// Creates a new entry. Callers normally only construct the initial
  /// (pending) entry directly; subsequent states are produced via
  /// [copyWith].
  const NetworkCallEntry({
    required this.id,
    required this.startTime,
    required this.method,
    required this.uri,
    required this.requestHeaders,
    required this.requestBody,
    required this.responseHeaders,
    required this.responseBody,
    required this.status,
    required this.client,
    this.statusCode,
    this.statusMessage,
    this.duration,
    this.requestSize,
    this.responseSize,
    this.errorMessage,
    this.replayOf,
    this.progress,
  });

  /// Process-unique id for this call. Also the correlation key
  /// (`callId`) shared by every [JalaEvent] belonging to this call.
  final String id;

  /// When the request was initiated.
  final DateTime startTime;

  /// HTTP method, uppercased (e.g. `GET`, `POST`).
  final String method;

  /// Full request URI.
  final Uri uri;

  /// Request headers, already redacted at capture time — raw sensitive
  /// values never enter the store.
  final Map<String, String> requestHeaders;

  /// Captured (and possibly redacted/truncated) request body.
  final CapturedBody requestBody;

  /// HTTP status code, or null while [status] is
  /// [JalaCallStatus.pending].
  final int? statusCode;

  /// HTTP status message (e.g. `OK`, `Not Found`), if known.
  final String? statusMessage;

  /// Response headers, already redacted at capture time.
  final Map<String, String> responseHeaders;

  /// Captured (and possibly redacted/truncated) response body.
  final CapturedBody responseBody;

  /// Wall-clock duration of the call, or null while pending.
  final Duration? duration;

  /// Best-effort request body size in bytes, if known.
  final int? requestSize;

  /// Best-effort response body size in bytes, if known.
  final int? responseSize;

  /// Current lifecycle status of the call.
  final JalaCallStatus status;

  /// Human-readable error message when [status] is
  /// [JalaCallStatus.error], otherwise null.
  final String? errorMessage;

  /// The `id` of the original [NetworkCallEntry] this call replays, or
  /// null if this is not a replay.
  final String? replayOf;

  /// Identifies which client/library captured this call, e.g. `'dio'`.
  final String client;

  /// The most recent upload/download progress observed for this call, or
  /// null if no [NetworkProgressEvent] has arrived yet (or the capturing
  /// adapter never observes progress for this kind of call — see B4 in
  /// docs/plans/track-b-v0.2.md).
  final NetworkProgressEvent? progress;

  /// Returns a copy of this entry with the given fields replaced.
  ///
  /// Nullable fields (e.g. [statusCode], [duration], [errorMessage]) use an
  /// internal sentinel so that passing an explicit `null` clears the field,
  /// while omitting the argument entirely leaves the current value intact.
  NetworkCallEntry copyWith({
    String? id,
    DateTime? startTime,
    String? method,
    Uri? uri,
    Map<String, String>? requestHeaders,
    CapturedBody? requestBody,
    Object? statusCode = _unset,
    Object? statusMessage = _unset,
    Map<String, String>? responseHeaders,
    CapturedBody? responseBody,
    Object? duration = _unset,
    Object? requestSize = _unset,
    Object? responseSize = _unset,
    JalaCallStatus? status,
    Object? errorMessage = _unset,
    Object? replayOf = _unset,
    String? client,
    Object? progress = _unset,
  }) {
    return NetworkCallEntry(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      method: method ?? this.method,
      uri: uri ?? this.uri,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: requestBody ?? this.requestBody,
      statusCode: identical(statusCode, _unset)
          ? this.statusCode
          : statusCode as int?,
      statusMessage: identical(statusMessage, _unset)
          ? this.statusMessage
          : statusMessage as String?,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      duration: identical(duration, _unset)
          ? this.duration
          : duration as Duration?,
      requestSize: identical(requestSize, _unset)
          ? this.requestSize
          : requestSize as int?,
      responseSize: identical(responseSize, _unset)
          ? this.responseSize
          : responseSize as int?,
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      replayOf: identical(replayOf, _unset)
          ? this.replayOf
          : replayOf as String?,
      client: client ?? this.client,
      progress: identical(progress, _unset)
          ? this.progress
          : progress as NetworkProgressEvent?,
    );
  }

  @override
  String toString() =>
      'NetworkCallEntry(id: $id, method: $method, uri: $uri, '
      'status: $status, statusCode: $statusCode)';
}
