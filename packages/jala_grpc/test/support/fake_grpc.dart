import 'dart:async';
import 'dart:convert';

import 'package:grpc/grpc.dart';

/// A stand-in for a protoc-generated message.
///
/// Exposes the two members [JalaGrpcInterceptor] duck-types —
/// `toProto3Json()` and `writeToBuffer()` — without pulling
/// `package:protobuf` into the test matrix.
class FakeMessage {
  const FakeMessage(this.fields);

  final Map<String, Object?> fields;

  Object? toProto3Json() => fields;

  List<int> writeToBuffer() => utf8.encode(jsonEncode(fields));
}

/// A message that is *not* protobuf-shaped: no `toProto3Json`, no
/// `writeToBuffer`. Exercises the metadata-only fallback.
class OpaqueMessage {
  const OpaqueMessage();
}

ClientMethod<Q, R> fakeMethod<Q, R>({
  String path = '/routeguide.RouteGuide/GetFeature',
}) {
  return ClientMethod<Q, R>(
    path,
    (Q value) => value is FakeMessage
        ? value.writeToBuffer()
        : const <int>[1, 2, 3],
    (List<int> value) => throw UnimplementedError('not deserialized in tests'),
  );
}

/// Builds a unary invoker that completes with [response], or fails with
/// [error]. Mirrors what `Client.$createUnaryCall` hands an interceptor.
ClientUnaryInvoker<Q, R> unaryInvoker<Q, R>({
  R? response,
  Object? error,
  Map<String, String> headers = const <String, String>{},
  Map<String, String> trailers = const <String, String>{},
}) {
  return (ClientMethod<Q, R> method, Q request, CallOptions options) {
    final call = FakeClientCall<Q, R>(
      method,
      Stream<Q>.value(request),
      options,
      responses: response == null ? const <Never>[] : <R>[response],
      error: error,
      headerMetadata: headers,
      trailerMetadata: trailers,
    );
    return ResponseFuture<R>(call);
  };
}

/// Builds a streaming invoker producing [responses], recording every request
/// message the interceptor forwards into [sentRequests].
ClientStreamingInvoker<Q, R> streamingInvoker<Q, R>({
  List<R> responses = const <Never>[],
  Object? error,
  Map<String, String> headers = const <String, String>{},
  Map<String, String> trailers = const <String, String>{},
  List<Q>? sentRequests,
}) {
  return (ClientMethod<Q, R> method, Stream<Q> requests, CallOptions options) {
    final call = FakeClientCall<Q, R>(
      method,
      requests,
      options,
      responses: responses,
      error: error,
      headerMetadata: headers,
      trailerMetadata: trailers,
      onRequest: sentRequests?.add,
    );
    return ResponseStream<R>(call);
  };
}

/// A [ClientCall] that never touches a socket: it drains the request stream
/// and replays canned responses/metadata.
///
/// Subclassing is the only way to hand `ResponseFuture`/`ResponseStream` a
/// call object — their constructors take one and nothing else.
class FakeClientCall<Q, R> extends ClientCall<Q, R> {
  // Explicit (not super) parameters: the request stream has to be readable
  // in the body to drive the fake, and a super parameter is not in scope
  // there.
  // ignore: use_super_parameters
  FakeClientCall(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options, {
    required List<R> responses,
    required Map<String, String> headerMetadata,
    required Map<String, String> trailerMetadata,
    Object? error,
    void Function(Q)? onRequest,
  }) : _responsesOut = responses,
       _headers = headerMetadata,
       _trailers = trailerMetadata,
       _error = error,
       _onRequest = onRequest,
       super(method, requests, options) {
    unawaited(_drive(requests));
  }

  final List<R> _responsesOut;
  final Map<String, String> _headers;
  final Map<String, String> _trailers;
  final Object? _error;
  final void Function(Q)? _onRequest;

  final _out = StreamController<R>();
  final _headersCompleter = Completer<Map<String, String>>();
  final _trailersCompleter = Completer<Map<String, String>>();

  Future<void> _drive(Stream<Q> requests) async {
    try {
      await for (final Q message in requests) {
        _onRequest?.call(message);
      }
    } on Object {
      // A failing request stream still terminates the call below.
    }
    _headersCompleter.complete(_headers);
    for (final R response in _responsesOut) {
      _out.add(response);
    }
    final Object? error = _error;
    if (error != null) {
      _out.addError(error);
      _trailersCompleter.completeError(error);
      // A real failed unary call has no trailers listener either — the
      // interceptor only reads them on success. Absorb it here so the test
      // run doesn't report an unhandled async error for realistic usage.
      unawaited(
        _trailersCompleter.future.catchError(
          (Object _) => const <String, String>{},
        ),
      );
    } else {
      _trailersCompleter.complete(_trailers);
    }
    await _out.close();
  }

  @override
  Stream<R> get response => _out.stream;

  @override
  Future<Map<String, String>> get headers => _headersCompleter.future;

  @override
  Future<Map<String, String>> get trailers => _trailersCompleter.future;

  @override
  Future<void> cancel() async {}
}

/// A [ClientChannel] subclass that hands back [FakeClientCall]s.
///
/// Exists to exercise the **real** wiring path: `Client.$createUnaryCall`
/// builds the interceptor chain and then calls `channel.createCall(...)`, so
/// a test that goes through `Client` proves the interceptor is invoked the
/// way a generated stub invokes it — not just when called directly.
///
/// Being channel-agnostic is the point. `GrpcWebClientChannel` is just
/// another `ClientChannelBase`, and interceptors are applied *above* the
/// channel by `Client`, so whatever holds for this fake holds for grpc-web
/// too. The grpc-web transport itself cannot be exercised here: its
/// `xhr_transport.dart` imports `dart:js_interop` and `package:web`, so it
/// does not load on the VM.
///
/// Subclassing (rather than implementing) is forced: `package:grpc` exports
/// the *concrete* HTTP/2 `ClientChannel`, not the abstract interface of the
/// same name, so `implements ClientChannel` would demand `host`, `port`,
/// `options`, `createConnection` and `getConnection`. Overriding
/// `createCall` means the connection machinery is never reached, so nothing
/// dials `fake.invalid`.
class FakeChannel extends ClientChannel {
  FakeChannel({
    this.response,
    this.error,
    this.headers = const <String, String>{},
    this.trailers = const <String, String>{},
  }) : super('fake.invalid');

  /// Single response message replayed for every call, or null for none.
  final Object? response;

  /// When set, the call terminates with this error instead.
  final Object? error;

  final Map<String, String> headers;
  final Map<String, String> trailers;

  /// Every method path this channel was asked to call, in order.
  final List<String> calls = <String>[];

  @override
  ClientCall<Q, R> createCall<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
  ) {
    calls.add(method.path);
    return FakeClientCall<Q, R>(
      method,
      requests,
      options,
      responses: response == null ? <R>[] : <R>[response as R],
      headerMetadata: headers,
      trailerMetadata: trailers,
      error: error,
    );
  }

}

/// Stands in for a protoc-generated client stub: a [Client] subclass whose
/// methods go through `$createUnaryCall` / `$createStreamingCall`, which is
/// where `package:grpc` applies interceptors.
class DemoClient extends Client {
  DemoClient(super.channel, {super.interceptors});

  static final ClientMethod<FakeMessage, FakeMessage> getFeature =
      fakeMethod<FakeMessage, FakeMessage>();

  static final ClientMethod<FakeMessage, FakeMessage> routeChat =
      fakeMethod<FakeMessage, FakeMessage>(
        path: '/routeguide.RouteGuide/RouteChat',
      );

  ResponseFuture<FakeMessage> unary(FakeMessage request) =>
      $createUnaryCall(getFeature, request);

  ResponseStream<FakeMessage> streaming(Stream<FakeMessage> requests) =>
      $createStreamingCall(routeChat, requests);
}
