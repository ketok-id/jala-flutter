import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:jala_core/jala_core.dart';

/// A `package:grpc` [ClientInterceptor] that captures every RPC made through
/// the clients it is attached to into `JalaBinding.instance`.
///
/// ```dart
/// final client = RouteGuideClient(
///   channel,
///   interceptors: <ClientInterceptor>[JalaGrpcInterceptor()],
/// );
/// ```
///
/// Reads global bindings via [JalaBinding.instance] instead of taking
/// constructor parameters, matching every other Jala adapter — a single
/// `Jala.initialize()` call configures each attached interceptor. When Jala
/// is disabled (or was never initialized) both hooks forward straight to
/// `invoker` with no capture work at all.
///
/// A bug in the capture logic itself must never break the host app's RPCs:
/// capture is wrapped in `try`/`catch`, and the invoker's own
/// [ResponseFuture] / [ResponseStream] is always returned **unchanged**, so
/// the caller keeps `cancel()`, `headers`, `trailers` and object identity.
///
/// ## What is captured
///
/// | | request message | response message(s) | status / trailers |
/// |---|---|---|---|
/// | unary | ✅ | ✅ | ✅ |
/// | streaming | sent bytes only | ❌ | ✅ |
///
/// **Streaming response messages cannot be captured.** [ResponseStream] is a
/// single-subscription stream whose only constructor takes a `ClientCall`
/// private to the call site, so this interceptor can neither tap it (that
/// would steal the app's subscription) nor rebuild an equivalent one. Only
/// the RPC envelope — method, metadata, status, trailers, duration — plus
/// request-side byte progress is recorded. See
/// docs/plans/track-g-v0.8-grpc.md.
///
/// **Mocking and throttling do not apply to gRPC.** Both need to fabricate
/// or delay a response, which requires constructing a [ResponseFuture] /
/// [ResponseStream] — impossible for the same reason. `JalaMockRegistry` and
/// `JalaThrottleRegistry` are simply not consulted here; an RPC is never
/// mocked, delayed, or dropped by Jala.
class JalaGrpcInterceptor extends ClientInterceptor {
  /// Creates an interceptor. [endpoint] is used verbatim as the host part of
  /// each captured entry's URI.
  ///
  /// A [ClientInterceptor] is never told which channel it is running on —
  /// that is private to the `Client` — so pass the channel's endpoint here
  /// if you want captured entries to show the real host. When omitted,
  /// entries fall back to [placeholderEndpoint], which documents "host
  /// unknown" without pretending to a URL that was never used.
  JalaGrpcInterceptor({this.endpoint});

  /// The gRPC endpoint the intercepted clients talk to, used only to build
  /// the captured entry's URI. Never dialled by Jala.
  final Uri? endpoint;

  /// Placeholder authority used when [endpoint] is omitted.
  static final Uri placeholderEndpoint = Uri.parse('grpc://unknown-endpoint');

  /// Value used for `NetworkCallEntry.client` on every entry this
  /// interceptor produces — the discriminator behind the `is:grpc` filter.
  static const String clientName = 'grpc';

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    final JalaBinding binding = JalaBinding.instance;
    if (!binding.isEnabled) return invoker(method, request, options);

    String? callId;
    Stopwatch? stopwatch;
    try {
      callId = JalaIdGenerator.next();
      stopwatch = Stopwatch()..start();
      final captured = _captureMessage(
        binding,
        request,
        () => method.requestSerializer(request),
      );
      _emitRequest(
        binding,
        callId: callId,
        method: method,
        options: options,
        rpcKind: 'unary',
        body: captured.body,
        size: captured.size,
      );
    } catch (_) {
      // A capture bug must never break the app's RPCs.
    }

    final ResponseFuture<R> response = invoker(method, request, options);
    final String? id = callId;
    if (id == null) return response;

    // `ResponseFuture` already holds the sole subscription to the call's
    // response stream (it folds it at construction), and a Future accepts
    // any number of listeners — so tapping here is free and steals nothing.
    unawaited(
      response.then(
        (R value) => _emitUnaryResponse(
          binding,
          callId: id,
          method: method,
          stopwatch: stopwatch,
          value: value,
          response: response,
        ),
        onError: (Object error, StackTrace _) =>
            _emitError(binding, callId: id, stopwatch: stopwatch, error: error),
      ),
    );
    return response;
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    ClientStreamingInvoker<Q, R> invoker,
  ) {
    final JalaBinding binding = JalaBinding.instance;
    if (!binding.isEnabled) return invoker(method, requests, options);

    String? callId;
    Stopwatch? stopwatch;
    Stream<Q> outgoing = requests;
    try {
      callId = JalaIdGenerator.next();
      stopwatch = Stopwatch()..start();
      // The request event is emitted immediately, before the first message
      // is produced, so a long-lived bidi RPC shows up as pending right
      // away rather than only once the app happens to send something —
      // matching `JalaGraphQLLink`'s subscription behavior.
      _emitRequest(
        binding,
        callId: callId,
        method: method,
        options: options,
        rpcKind: _streamingKind(method),
        body: CapturedBody.none,
        size: null,
      );
      outgoing = _tapRequests(
        binding,
        callId: callId,
        method: method,
        requests: requests,
      );
    } catch (_) {
      // A capture bug must never break the app's RPCs; send the original
      // stream, just without request-side progress for this call.
      outgoing = requests;
    }

    final ResponseStream<R> response = invoker(method, outgoing, options);
    final String? id = callId;
    if (id == null) return response;

    // Deliberately NOT listening to `response` itself — it is a
    // single-subscription stream and doing so would steal the app's
    // messages. `trailers` is a Future and safe to tap.
    unawaited(
      response.trailers.then(
        (Map<String, String> trailers) => _emitStreamingCompletion(
          binding,
          callId: id,
          stopwatch: stopwatch,
          trailers: trailers,
        ),
        onError: (Object error, StackTrace _) =>
            _emitError(binding, callId: id, stopwatch: stopwatch, error: error),
      ),
    );
    return response;
  }

  /// Wraps the outgoing request stream so sent bytes are reported as
  /// [NetworkProgressEvent]s — the same "Sent X" line the HTTP adapters
  /// produce for an upload. Lazy: elements are forwarded one at a time as
  /// the transport pulls them; nothing is buffered.
  Stream<Q> _tapRequests<Q, R>(
    JalaBinding binding, {
    required String callId,
    required ClientMethod<Q, R> method,
    required Stream<Q> requests,
  }) {
    var sent = 0;
    return requests.map((Q message) {
      try {
        sent += _bytesOf(message, () => method.requestSerializer(message))
                ?.length ??
            0;
        binding.bus.emit(
          NetworkProgressEvent(
            callId: callId,
            timestamp: DateTime.now(),
            sentBytes: sent,
            receivedBytes: 0,
          ),
        );
      } catch (_) {
        // A capture bug must never break the app's RPCs.
      }
      return message;
    });
  }

  void _emitRequest<Q, R>(
    JalaBinding binding, {
    required String callId,
    required ClientMethod<Q, R> method,
    required CallOptions options,
    required String rpcKind,
    required CapturedBody body,
    required int? size,
  }) {
    binding.bus.emit(
      NetworkRequestEvent(
        callId: callId,
        timestamp: DateTime.now(),
        // gRPC is always POST over HTTP/2; the inspector shows `rpcKind`
        // rather than this, but the field is non-nullable and this is the
        // truthful value.
        method: 'POST',
        uri: binding.config.redactor.redactUri(_uriFor(method)),
        headers: binding.config.redactor.redactHeaders(options.metadata),
        body: body,
        size: size,
        client: clientName,
        operationName: methodNameOf(method.path),
        rpcKind: rpcKind,
      ),
    );
  }

  void _emitUnaryResponse<Q, R>(
    JalaBinding binding, {
    required String callId,
    required ClientMethod<Q, R> method,
    required Stopwatch? stopwatch,
    required R value,
    required ResponseFuture<R> response,
  }) {
    final captured = _captureMessage(binding, value, null);
    // headers/trailers have both resolved by the time the value has.
    unawaited(
      _metadataOf(response).then((({
        Map<String, String> headers,
        Map<String, String> trailers,
      }) metadata) {
        try {
          binding.bus.emit(
            NetworkResponseEvent(
              callId: callId,
              timestamp: DateTime.now(),
              // A transport-successful RPC is HTTP 200; the gRPC outcome
              // lives in `grpcStatusCode`.
              statusCode: 200,
              statusMessage: 'OK',
              headers: binding.config.redactor.redactHeaders(metadata.headers),
              body: captured.body,
              size: captured.size,
              duration: stopwatch?.elapsed ?? Duration.zero,
              grpcStatusCode: 0,
              trailers: binding.config.redactor.redactHeaders(
                metadata.trailers,
              ),
            ),
          );
        } catch (_) {
          // A capture bug must never break the app's RPCs.
        }
      }),
    );
  }

  void _emitStreamingCompletion(
    JalaBinding binding, {
    required String callId,
    required Stopwatch? stopwatch,
    required Map<String, String> trailers,
  }) {
    try {
      binding.bus.emit(
        NetworkResponseEvent(
          callId: callId,
          timestamp: DateTime.now(),
          statusCode: 200,
          statusMessage: 'OK',
          headers: const <String, String>{},
          // Response messages are not capturable for a streaming RPC — see
          // the class doc. An empty body is the honest record; the UI
          // labels it rather than showing a misleading empty payload list.
          body: CapturedBody.none,
          duration: stopwatch?.elapsed ?? Duration.zero,
          grpcStatusCode: 0,
          trailers: binding.config.redactor.redactHeaders(trailers),
        ),
      );
    } catch (_) {
      // A capture bug must never break the app's RPCs.
    }
  }

  void _emitError(
    JalaBinding binding, {
    required String callId,
    required Stopwatch? stopwatch,
    required Object error,
  }) {
    try {
      final GrpcError? grpcError = error is GrpcError ? error : null;
      if (grpcError?.code == StatusCode.cancelled) {
        binding.bus.emit(
          NetworkCancelEvent(callId: callId, timestamp: DateTime.now()),
        );
        return;
      }
      binding.bus.emit(
        NetworkErrorEvent(
          callId: callId,
          timestamp: DateTime.now(),
          errorMessage: _describe(error, grpcError),
          statusCode: 200,
          duration: stopwatch?.elapsed,
          grpcStatusCode: grpcError?.code,
          trailers: grpcError?.trailers,
        ),
      );
    } catch (_) {
      // A capture bug must never break the app's RPCs.
    }
  }

  /// Collects a response's headers and trailers, tolerating either failing
  /// (a cancelled call completes `trailers` with an error).
  Future<({Map<String, String> headers, Map<String, String> trailers})>
  _metadataOf(Response response) async {
    Map<String, String> headers = const <String, String>{};
    Map<String, String> trailers = const <String, String>{};
    try {
      headers = await response.headers;
    } on Object {
      // Metadata is best-effort; an absent map is not a capture failure.
    }
    try {
      trailers = await response.trailers;
    } on Object {
      // As above.
    }
    return (headers: headers, trailers: trailers);
  }

  Uri _uriFor<Q, R>(ClientMethod<Q, R> method) =>
      (endpoint ?? placeholderEndpoint).replace(path: method.path);

  String _streamingKind<Q, R>(ClientMethod<Q, R> method) {
    // `ClientInterceptor` cannot distinguish server- from client-streaming:
    // both arrive here as a request stream plus a response stream. `bidi`
    // is the only description that is never wrong about what this hook can
    // observe; a precise kind would require generated-stub metadata gRPC
    // does not hand to interceptors.
    return 'bidi';
  }

  /// The method name from a gRPC path (`/pkg.Service/Method` -> `Method`).
  /// Returns the whole path when it does not have the expected shape.
  static String methodNameOf(String path) {
    final int slash = path.lastIndexOf('/');
    if (slash == -1 || slash == path.length - 1) return path;
    return path.substring(slash + 1);
  }

  /// The fully-qualified service from a gRPC path
  /// (`/pkg.Service/Method` -> `pkg.Service`), or null when absent.
  static String? serviceNameOf(String path) {
    final String trimmed = path.startsWith('/') ? path.substring(1) : path;
    final int slash = trimmed.indexOf('/');
    if (slash <= 0) return null;
    return trimmed.substring(0, slash);
  }

  /// Captures [message] as proto3 JSON where the generated type supports it,
  /// falling back to serialized-byte metadata, and reports its wire size.
  ///
  /// Redaction runs through [CapturedBody.captureRedacted]: proto3 JSON is a
  /// decoded `Map`, exactly the shape that used to bypass body redaction
  /// before 0.8.0.
  ///
  /// [serialize] is supplied on the request side, where
  /// `ClientMethod.requestSerializer` is available. `ClientMethod` exposes no
  /// *response* serializer — only a deserializer — so the response side
  /// falls back to the generated `writeToBuffer()`.
  static ({CapturedBody body, int? size}) _captureMessage(
    JalaBinding binding,
    Object? message,
    List<int> Function()? serialize,
  ) {
    final int maxBytes = binding.config.maxBodyBytes;
    final JalaRedactor redactor = binding.config.redactor;
    final List<int>? bytes = _bytesOf(message, serialize);
    try {
      // Duck-typed rather than depending on package:protobuf: every
      // protoc-generated message has toProto3Json(), but a hand-rolled or
      // non-protobuf codec need not.
      final dynamic json = (message as dynamic).toProto3Json();
      if (json != null) {
        return (
          body: CapturedBody.captureRedacted(
            json,
            redactor: redactor,
            contentType: 'application/json',
            maxBytes: maxBytes,
          ),
          size: bytes?.length,
        );
      }
    } on Object {
      // No proto3Json support (or it threw) — fall through to bytes.
    }
    if (bytes == null) return (body: CapturedBody.none, size: null);
    return (
      // Not a textual content-type, so this retains size metadata only —
      // Jala never holds raw protobuf payloads.
      body: CapturedBody.captureRedacted(
        bytes,
        redactor: redactor,
        contentType: 'application/grpc+proto',
        maxBytes: maxBytes,
      ),
      size: bytes.length,
    );
  }

  /// Best-effort serialized bytes for [message].
  static List<int>? _bytesOf(Object? message, List<int> Function()? serialize) {
    if (serialize != null) {
      try {
        return serialize();
      } on Object {
        return null;
      }
    }
    try {
      final dynamic raw = (message as dynamic).writeToBuffer();
      return raw is List<int> ? raw : null;
    } on Object {
      return null;
    }
  }

  static String _describe(Object error, GrpcError? grpcError) {
    if (grpcError == null) return error.toString();
    final String name = _statusName(grpcError.code);
    final String? message = grpcError.message;
    return message == null || message.isEmpty ? name : '$name: $message';
  }

  /// Canonical gRPC status name for [code] (`5` -> `NOT_FOUND`).
  static String _statusName(int code) =>
      code >= 0 && code < _statusNames.length
      ? _statusNames[code]
      : 'CODE_$code';

  static const List<String> _statusNames = <String>[
    'OK',
    'CANCELLED',
    'UNKNOWN',
    'INVALID_ARGUMENT',
    'DEADLINE_EXCEEDED',
    'NOT_FOUND',
    'ALREADY_EXISTS',
    'PERMISSION_DENIED',
    'RESOURCE_EXHAUSTED',
    'FAILED_PRECONDITION',
    'ABORTED',
    'OUT_OF_RANGE',
    'UNIMPLEMENTED',
    'INTERNAL',
    'UNAVAILABLE',
    'DATA_LOSS',
    'UNAUTHENTICATED',
  ];
}
