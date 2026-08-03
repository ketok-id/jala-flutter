/// gRPC demo calls for the QA rig.
///
/// Drives the real [JalaGrpcInterceptor] — not fabricated events — so the
/// inspector's gRPC presentation (kind chip, status names, trailers, the
/// streaming note) can be checked on a device. The transport is a canned
/// in-memory [ClientCall] rather than a live server, so the rig has no
/// network dependency and works offline and in CI.
library;

import 'dart:async';
import 'dart:convert';

import 'package:grpc/grpc.dart';
import 'package:jala_grpc/jala_grpc.dart';

/// Stands in for a protoc-generated message: exposes the two members the
/// interceptor duck-types, without the example needing `package:protobuf`
/// or a `.proto` build step.
class DemoMessage {
  const DemoMessage(this.fields);

  final Map<String, Object?> fields;

  Object? toProto3Json() => fields;

  List<int> writeToBuffer() => utf8.encode(jsonEncode(fields));
}

final JalaGrpcInterceptor _interceptor = JalaGrpcInterceptor(
  endpoint: Uri.parse('grpc://routeguide.example.com'),
);

ClientMethod<DemoMessage, DemoMessage> _method(String path) {
  return ClientMethod<DemoMessage, DemoMessage>(
    path,
    (DemoMessage value) => value.writeToBuffer(),
    (List<int> value) => const DemoMessage(<String, Object?>{}),
  );
}

/// A successful unary RPC: request and response messages both captured.
Future<void> grpcUnaryOk() async {
  await _interceptor.interceptUnary<DemoMessage, DemoMessage>(
    _method('/routeguide.RouteGuide/GetFeature'),
    const DemoMessage(<String, Object?>{
      'latitude': 409146138,
      'longitude': -746188906,
    }),
    CallOptions(metadata: <String, String>{
      'authorization': 'Bearer demo-token-never-stored',
      'x-tenant': 'acme',
    }),
    _invoker(
      response: const DemoMessage(<String, Object?>{
        'name': 'Berkshire Valley Management Area Trail',
      }),
      trailers: const <String, String>{'grpc-status': '0'},
    ),
  );
}

/// A failed unary RPC — shows the gRPC status name and error colouring on a
/// call that is nonetheless an HTTP 200.
Future<void> grpcUnaryNotFound() async {
  try {
    await _interceptor.interceptUnary<DemoMessage, DemoMessage>(
      _method('/routeguide.RouteGuide/GetFeature'),
      const DemoMessage(<String, Object?>{'latitude': 0, 'longitude': 0}),
      CallOptions(),
      _invoker(error: const GrpcError.notFound('no feature at that point')),
    );
  } on GrpcError {
    // Expected — the rig only needs the captured entry.
  }
}

/// A unary RPC carrying a secret, to confirm capture-time body redaction
/// reaches proto3-JSON messages.
Future<void> grpcUnaryWithSecret() async {
  await _interceptor.interceptUnary<DemoMessage, DemoMessage>(
    _method('/auth.Auth/Login'),
    const DemoMessage(<String, Object?>{
      'username': 'ada',
      'password': 'hunter2',
    }),
    CallOptions(),
    _invoker(
      response: const DemoMessage(<String, Object?>{
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.demo.signature',
      }),
    ),
  );
}

/// A streaming RPC — the entry records its envelope and sent bytes; the
/// detail screen explains why there is no response body.
Future<void> grpcStreaming() async {
  final ResponseStream<DemoMessage> stream = _interceptor
      .interceptStreaming<DemoMessage, DemoMessage>(
        _method('/routeguide.RouteGuide/RouteChat'),
        Stream<DemoMessage>.fromIterable(<DemoMessage>[
          const DemoMessage(<String, Object?>{'message': 'first'}),
          const DemoMessage(<String, Object?>{'message': 'second'}),
        ]),
        CallOptions(),
        _streamingInvoker(
          responses: <DemoMessage>[
            const DemoMessage(<String, Object?>{'message': 'ack 1'}),
            const DemoMessage(<String, Object?>{'message': 'ack 2'}),
          ],
          trailers: const <String, String>{'grpc-status': '0'},
        ),
      );
  await stream.drain<void>();
}

ClientUnaryInvoker<DemoMessage, DemoMessage> _invoker({
  DemoMessage? response,
  Object? error,
  Map<String, String> trailers = const <String, String>{},
}) {
  return (method, request, options) => ResponseFuture<DemoMessage>(
    _CannedCall<DemoMessage, DemoMessage>(
      method,
      Stream<DemoMessage>.value(request),
      options,
      responses: response == null ? const <DemoMessage>[] : <DemoMessage>[
        response,
      ],
      error: error,
      trailerMetadata: trailers,
    ),
  );
}

ClientStreamingInvoker<DemoMessage, DemoMessage> _streamingInvoker({
  List<DemoMessage> responses = const <DemoMessage>[],
  Map<String, String> trailers = const <String, String>{},
}) {
  return (method, requests, options) => ResponseStream<DemoMessage>(
    _CannedCall<DemoMessage, DemoMessage>(
      method,
      requests,
      options,
      responses: responses,
      trailerMetadata: trailers,
    ),
  );
}

/// A [ClientCall] that never opens a socket: it drains the request stream
/// and replays canned responses and metadata after a short delay, so the rig
/// shows a realistic pending → complete transition.
///
/// Subclassing is the only way to hand `ResponseFuture` / `ResponseStream` a
/// call object — their constructors take one and nothing else.
class _CannedCall<Q, R> extends ClientCall<Q, R> {
  // Explicit (not super) parameters: the request stream has to be readable
  // in the body, and a super parameter is not in scope there.
  // ignore: use_super_parameters
  _CannedCall(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options, {
    required List<R> responses,
    required Map<String, String> trailerMetadata,
    Object? error,
  }) : _out = responses,
       _trailers = trailerMetadata,
       _error = error,
       super(method, requests, options) {
    unawaited(_drive(requests));
  }

  final List<R> _out;
  final Map<String, String> _trailers;
  final Object? _error;

  final StreamController<R> _responses = StreamController<R>();
  final Completer<Map<String, String>> _headersDone =
      Completer<Map<String, String>>();
  final Completer<Map<String, String>> _trailersDone =
      Completer<Map<String, String>>();

  Future<void> _drive(Stream<Q> requests) async {
    await requests.drain<void>();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _headersDone.complete(const <String, String>{
      'content-type': 'application/grpc',
    });
    for (final R message in _out) {
      _responses.add(message);
    }
    final Object? error = _error;
    if (error != null) {
      _responses.addError(error);
      _trailersDone.completeError(error);
      unawaited(
        _trailersDone.future.catchError((Object _) => const <String, String>{}),
      );
    } else {
      _trailersDone.complete(_trailers);
    }
    await _responses.close();
  }

  @override
  Stream<R> get response => _responses.stream;

  @override
  Future<Map<String, String>> get headers => _headersDone.future;

  @override
  Future<Map<String, String>> get trailers => _trailersDone.future;

  @override
  Future<void> cancel() async {}
}
