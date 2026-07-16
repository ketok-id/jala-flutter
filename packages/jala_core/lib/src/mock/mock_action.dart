/// Kind of synthetic transport failure a [MockFailure] can produce.
enum MockFailureKind {
  /// Simulates a connection / receive timeout.
  timeout,

  /// Simulates a DNS / connection failure before any response.
  connectionError,
}

/// What a matching [JalaMockRule] does to a request.
///
/// All variants may carry an optional [delay] so adapters can sleep before
/// resolving, rejecting, or passing through.
sealed class MockAction {
  const MockAction({this.delay});

  /// Artificial latency applied before the action takes effect.
  final Duration? delay;

  /// Serializes this action for persistence.
  Map<String, dynamic> toJson();

  /// Deserializes an action from [json]. Throws [FormatException] on unknown
  /// types or malformed fields.
  static MockAction fromJson(Map<String, dynamic> json) {
    final String? type = json['type'] as String?;
    final Duration? delay = _durationFromJson(json['delayMs']);
    switch (type) {
      case 'response':
        final Object? statusRaw = json['statusCode'];
        final int statusCode = statusRaw is int
            ? statusRaw
            : int.tryParse('$statusRaw') ??
                  (throw const FormatException(
                    'MockResponse missing statusCode',
                  ));
        final Object? headersRaw = json['headers'];
        final Map<String, String> headers = <String, String>{};
        if (headersRaw is Map) {
          headersRaw.forEach((Object? k, Object? v) {
            headers['$k'] = '$v';
          });
        }
        return MockResponse(
          statusCode: statusCode,
          headers: headers,
          body: json['body'] as String? ?? '',
          delay: delay,
        );
      case 'failure':
        final String kindName = json['kind'] as String? ?? 'connectionError';
        final MockFailureKind kind = MockFailureKind.values.firstWhere(
          (MockFailureKind k) => k.name == kindName,
          orElse: () => MockFailureKind.connectionError,
        );
        return MockFailure(kind: kind, delay: delay);
      case 'delay':
        final Duration d =
            delay ??
            (throw const FormatException('MockDelay requires delayMs'));
        return MockDelay(delay: d);
      default:
        throw FormatException('Unknown MockAction type: $type');
    }
  }

  static Duration? _durationFromJson(Object? ms) {
    if (ms == null) return null;
    final int? value = ms is int ? ms : int.tryParse('$ms');
    if (value == null) return null;
    return Duration(milliseconds: value);
  }

  static int? _durationToJson(Duration? d) => d?.inMilliseconds;
}

/// Short-circuit with a canned HTTP response.
class MockResponse extends MockAction {
  /// Creates a canned response action.
  const MockResponse({
    required this.statusCode,
    this.headers = const <String, String>{},
    this.body = '',
    super.delay,
  });

  /// HTTP status code to return.
  final int statusCode;

  /// Response headers (not redacted — they are authored by the user).
  final Map<String, String> headers;

  /// Response body as text; adapters encode to bytes when needed.
  final String body;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'response',
    'statusCode': statusCode,
    'headers': headers,
    'body': body,
    if (delay != null) 'delayMs': MockAction._durationToJson(delay),
  };
}

/// Short-circuit with a synthetic transport failure.
class MockFailure extends MockAction {
  /// Creates a failure action.
  const MockFailure({
    this.kind = MockFailureKind.connectionError,
    super.delay,
  });

  /// Which failure shape adapters should produce.
  final MockFailureKind kind;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'failure',
    'kind': kind.name,
    if (delay != null) 'delayMs': MockAction._durationToJson(delay),
  };
}

/// Pass the request through to the real network after [delay].
class MockDelay extends MockAction {
  /// Creates a delay-only action. [delay] is required.
  const MockDelay({required Duration delay}) : super(delay: delay);

  @override
  Duration get delay => super.delay!;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'delay',
    'delayMs': MockAction._durationToJson(delay),
  };
}
