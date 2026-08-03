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
    final call = _FakeClientCall<Q, R>(
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
    final call = _FakeClientCall<Q, R>(
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
class _FakeClientCall<Q, R> extends ClientCall<Q, R> {
  // Explicit (not super) parameters: the request stream has to be readable
  // in the body to drive the fake, and a super parameter is not in scope
  // there.
  // ignore: use_super_parameters
  _FakeClientCall(
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
