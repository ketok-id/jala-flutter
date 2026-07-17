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
    this.mockRuleId,
    this.progress,
    this.operationName,
    this.operationType,
    this.throttledBy,
    this.payloads = const <CapturedBody>[],
    this.payloadCount = 0,
    this.imported = false,
  });

  /// Deserializes an entry previously produced by [toJson] (used by
  /// `JalaSessionCodec` — see docs/plans/track-e-v0.5.md E1). `progress` is
  /// transient and was never serialized, so a decoded entry never has one.
  ///
  /// Throws [FormatException] on missing/malformed required fields or an
  /// unrecognized `status`.
  factory NetworkCallEntry.fromJson(Map<String, Object?> json) {
    final String? id = json['id'] as String?;
    final String? startTimeRaw = json['startTime'] as String?;
    final String? method = json['method'] as String?;
    final String? uriRaw = json['uri'] as String?;
    final String? statusName = json['status'] as String?;
    final String? client = json['client'] as String?;
    if (id == null ||
        startTimeRaw == null ||
        method == null ||
        uriRaw == null ||
        statusName == null ||
        client == null) {
      throw const FormatException('NetworkCallEntry missing required field');
    }
    JalaCallStatus? status;
    for (final JalaCallStatus candidate in JalaCallStatus.values) {
      if (candidate.name == statusName) {
        status = candidate;
        break;
      }
    }
    if (status == null) {
      throw FormatException('Unknown JalaCallStatus: $statusName');
    }
    final Object? durationMicros = json['durationMicros'];
    final Object? payloadsRaw = json['payloads'];
    return NetworkCallEntry(
      id: id,
      startTime: DateTime.parse(startTimeRaw),
      method: method,
      uri: Uri.parse(uriRaw),
      requestHeaders: _stringMapFromJson(json['requestHeaders']),
      requestBody: _bodyFromJson(json['requestBody']),
      statusCode: json['statusCode'] as int?,
      statusMessage: json['statusMessage'] as String?,
      responseHeaders: _stringMapFromJson(json['responseHeaders']),
      responseBody: _bodyFromJson(json['responseBody']),
      duration: durationMicros == null
          ? null
          : Duration(microseconds: durationMicros as int),
      requestSize: json['requestSize'] as int?,
      responseSize: json['responseSize'] as int?,
      status: status,
      errorMessage: json['errorMessage'] as String?,
      replayOf: json['replayOf'] as String?,
      mockRuleId: json['mockRuleId'] as String?,
      client: client,
      operationName: json['operationName'] as String?,
      operationType: json['operationType'] as String?,
      throttledBy: json['throttledBy'] as String?,
      payloads: payloadsRaw is List
          ? payloadsRaw.map(_bodyFromJson).toList(growable: false)
          : const <CapturedBody>[],
      payloadCount: json['payloadCount'] as int? ?? 0,
      imported: json['imported'] as bool? ?? false,
    );
  }

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

  /// The id of the [JalaMockRule] that handled this call, or null if the
  /// request was not matched by the mock registry.
  final String? mockRuleId;

  /// Identifies which client/library captured this call, e.g. `'dio'`.
  final String client;

  /// The most recent upload/download progress observed for this call, or
  /// null if no [NetworkProgressEvent] has arrived yet (or the capturing
  /// adapter never observes progress for this kind of call — see B4 in
  /// docs/plans/track-b-v0.2.md).
  final NetworkProgressEvent? progress;

  /// GraphQL operation name (e.g. `GetUser`), populated from a matching
  /// `NetworkRequestEvent.operationName` when this call is a GraphQL
  /// operation captured by a binding such as `jala_graphql` (see
  /// docs/plans/track-d-v0.4.md D1/D3). Null for plain HTTP calls.
  final String? operationName;

  /// GraphQL operation type — `query`, `mutation`, or `subscription` —
  /// when [operationName] is non-null. Null for plain HTTP calls.
  final String? operationType;

  /// The id of the `JalaThrottleProfile` that throttled this call (see
  /// `JalaThrottleRegistry`, docs/plans/track-e-v0.5.md E1/E2), or null if
  /// throttling was off or did not apply to this call.
  final String? throttledBy;

  /// GraphQL subscription payloads observed for this call, oldest first,
  /// capped at `JalaConfig.maxSubscriptionPayloads` (a per-call ring
  /// buffer — see [NetworkSubscriptionPayloadEvent] and
  /// `JalaStore`). Empty for non-subscription calls.
  final List<CapturedBody> payloads;

  /// Total number of subscription payloads ever observed for this call —
  /// unlike [payloads], never reduced by ring-buffer eviction. Mirrors
  /// `WsConnectionEntry.frameCount`.
  final int payloadCount;

  /// Whether this entry was produced by `JalaStore.importSession` rather
  /// than live capture. Set by the store's import path only — never true
  /// for a freshly captured call.
  final bool imported;

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
    Object? mockRuleId = _unset,
    String? client,
    Object? progress = _unset,
    Object? operationName = _unset,
    Object? operationType = _unset,
    Object? throttledBy = _unset,
    List<CapturedBody>? payloads,
    int? payloadCount,
    bool? imported,
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
      mockRuleId: identical(mockRuleId, _unset)
          ? this.mockRuleId
          : mockRuleId as String?,
      client: client ?? this.client,
      progress: identical(progress, _unset)
          ? this.progress
          : progress as NetworkProgressEvent?,
      operationName: identical(operationName, _unset)
          ? this.operationName
          : operationName as String?,
      operationType: identical(operationType, _unset)
          ? this.operationType
          : operationType as String?,
      throttledBy: identical(throttledBy, _unset)
          ? this.throttledBy
          : throttledBy as String?,
      payloads: payloads ?? this.payloads,
      payloadCount: payloadCount ?? this.payloadCount,
      imported: imported ?? this.imported,
    );
  }

  /// Serializes this entry for `JalaSessionCodec` (see
  /// docs/plans/track-e-v0.5.md E1). [progress] is transient (live-capture
  /// UI state) and is deliberately never serialized — a decoded entry
  /// simply has no progress.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'startTime': startTime.toIso8601String(),
    'method': method,
    'uri': uri.toString(),
    'requestHeaders': requestHeaders,
    'requestBody': requestBody.toJson(),
    if (statusCode != null) 'statusCode': statusCode,
    if (statusMessage != null) 'statusMessage': statusMessage,
    'responseHeaders': responseHeaders,
    'responseBody': responseBody.toJson(),
    if (duration != null) 'durationMicros': duration!.inMicroseconds,
    if (requestSize != null) 'requestSize': requestSize,
    if (responseSize != null) 'responseSize': responseSize,
    'status': status.name,
    if (errorMessage != null) 'errorMessage': errorMessage,
    if (replayOf != null) 'replayOf': replayOf,
    if (mockRuleId != null) 'mockRuleId': mockRuleId,
    'client': client,
    if (operationName != null) 'operationName': operationName,
    if (operationType != null) 'operationType': operationType,
    if (throttledBy != null) 'throttledBy': throttledBy,
    if (payloads.isNotEmpty)
      'payloads': payloads.map((CapturedBody p) => p.toJson()).toList(),
    'payloadCount': payloadCount,
    'imported': imported,
  };

  static Map<String, String> _stringMapFromJson(Object? raw) {
    if (raw is! Map) return const <String, String>{};
    return raw.map(
      (Object? key, Object? value) => MapEntry<String, String>(
        key.toString(),
        value.toString(),
      ),
    );
  }

  static CapturedBody _bodyFromJson(Object? raw) {
    if (raw is! Map) return CapturedBody.none;
    return CapturedBody.fromJson(Map<String, Object?>.from(raw));
  }

  @override
  String toString() =>
      'NetworkCallEntry(id: $id, method: $method, uri: $uri, '
      'status: $status, statusCode: $statusCode)';
}
