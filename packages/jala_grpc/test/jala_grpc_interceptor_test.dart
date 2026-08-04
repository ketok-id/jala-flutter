import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_grpc/jala_grpc.dart';
import 'package:test/test.dart';

import 'support/fake_grpc.dart';

/// Flushes pending microtasks so async event-bus deliveries settle.
Future<void> pump() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

NetworkCallEntry get onlyEntry => JalaBinding.instance.store.entries.single;

void main() {
  tearDown(JalaBinding.resetForTesting);

  group('unary RPCs', () {
    test('captures method, message, status and trailers', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final interceptor = JalaGrpcInterceptor(
        endpoint: Uri.parse('grpc://api.example.com'),
      );

      final result = await interceptor.interceptUnary<FakeMessage, FakeMessage>(
        fakeMethod<FakeMessage, FakeMessage>(),
        const FakeMessage(<String, Object?>{'name': 'ada'}),
        CallOptions(metadata: <String, String>{'x-tenant': 'acme'}),
        unaryInvoker<FakeMessage, FakeMessage>(
          response: const FakeMessage(<String, Object?>{'id': 7}),
          headers: const <String, String>{'content-type': 'application/grpc'},
          trailers: const <String, String>{'grpc-status': '0'},
        ),
      );
      expect(result.fields['id'], 7);
      await pump();

      final entry = onlyEntry;
      expect(entry.client, 'grpc');
      expect(entry.rpcKind, 'unary');
      expect(entry.operationName, 'GetFeature');
      expect(entry.uri.path, '/routeguide.RouteGuide/GetFeature');
      expect(entry.uri.host, 'api.example.com');
      expect(entry.requestHeaders['x-tenant'], 'acme');
      expect(entry.requestBody.text, '{"name":"ada"}');
      expect(entry.responseBody.text, '{"id":7}');
      expect(entry.status, JalaCallStatus.success);
      expect(entry.grpcStatusCode, 0);
      expect(entry.trailers['grpc-status'], '0');
      expect(entry.responseHeaders['content-type'], 'application/grpc');
    });

    test('a GrpcError becomes an error entry with its status code', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final interceptor = JalaGrpcInterceptor();

      await expectLater(
        interceptor.interceptUnary<FakeMessage, FakeMessage>(
          fakeMethod<FakeMessage, FakeMessage>(),
          const FakeMessage(<String, Object?>{}),
          CallOptions(),
          unaryInvoker<FakeMessage, FakeMessage>(
            error: const GrpcError.notFound('no such feature'),
          ),
        ),
        throwsA(isA<GrpcError>()),
      );
      await pump();

      final entry = onlyEntry;
      expect(entry.status, JalaCallStatus.error);
      expect(entry.grpcStatusCode, StatusCode.notFound);
      expect(entry.errorMessage, 'NOT_FOUND: no such feature');
    });

    test('a cancelled RPC is recorded as cancelled, not failed', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final interceptor = JalaGrpcInterceptor();

      await expectLater(
        interceptor.interceptUnary<FakeMessage, FakeMessage>(
          fakeMethod<FakeMessage, FakeMessage>(),
          const FakeMessage(<String, Object?>{}),
          CallOptions(),
          unaryInvoker<FakeMessage, FakeMessage>(
            error: const GrpcError.cancelled('client went away'),
          ),
        ),
        throwsA(isA<GrpcError>()),
      );
      await pump();

      expect(onlyEntry.status, JalaCallStatus.cancelled);
    });

    test('the caller gets the invoker ResponseFuture itself', () async {
      // Identity matters: the app keeps cancel()/headers/trailers, and the
      // future must not be re-wrapped into something that drops them.
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      late ResponseFuture<FakeMessage> produced;
      final ClientUnaryInvoker<FakeMessage, FakeMessage> inner =
          unaryInvoker<FakeMessage, FakeMessage>(
            response: const FakeMessage(<String, Object?>{}),
          );

      final returned = JalaGrpcInterceptor()
          .interceptUnary<FakeMessage, FakeMessage>(
            fakeMethod<FakeMessage, FakeMessage>(),
            const FakeMessage(<String, Object?>{}),
            CallOptions(),
            (method, request, options) =>
                produced = inner(method, request, options),
          );

      expect(identical(returned, produced), isTrue);
      await returned;
      await pump();
    });

    test('a non-protobuf message degrades to metadata-only capture', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));

      await JalaGrpcInterceptor()
          .interceptUnary<OpaqueMessage, OpaqueMessage>(
            fakeMethod<OpaqueMessage, OpaqueMessage>(),
            const OpaqueMessage(),
            CallOptions(),
            unaryInvoker<OpaqueMessage, OpaqueMessage>(
              response: const OpaqueMessage(),
            ),
          );
      await pump();

      final entry = onlyEntry;
      // requestSerializer still yields bytes; the response has neither
      // toProto3Json nor writeToBuffer, so nothing is retained for it.
      expect(entry.requestBody.kind, BodyKind.bytes);
      expect(entry.requestBody.text, isNull);
      expect(entry.responseBody.kind, BodyKind.none);
      expect(entry.status, JalaCallStatus.success);
    });
  });

  group('streaming RPCs', () {
    test('captures the envelope and reports sent bytes', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final sent = <FakeMessage>[];

      final stream = JalaGrpcInterceptor()
          .interceptStreaming<FakeMessage, FakeMessage>(
            fakeMethod<FakeMessage, FakeMessage>(
              path: '/routeguide.RouteGuide/RouteChat',
            ),
            Stream<FakeMessage>.fromIterable(<FakeMessage>[
              const FakeMessage(<String, Object?>{'a': 1}),
              const FakeMessage(<String, Object?>{'b': 2}),
            ]),
            CallOptions(),
            streamingInvoker<FakeMessage, FakeMessage>(
              responses: <FakeMessage>[
                const FakeMessage(<String, Object?>{'r': 1}),
              ],
              trailers: const <String, String>{'grpc-status': '0'},
              sentRequests: sent,
            ),
          );
      await stream.toList();
      await pump();

      // Every request message still reached the transport.
      expect(sent, hasLength(2));

      final entry = onlyEntry;
      expect(entry.rpcKind, 'bidi');
      expect(entry.operationName, 'RouteChat');
      expect(entry.status, JalaCallStatus.success);
      expect(entry.trailers['grpc-status'], '0');
      // Request-side bytes are reported as progress, since a streaming
      // request body has no single message to store.
      expect(entry.progress?.sentBytes, greaterThan(0));
    });

    test('response messages are not captured (documented limitation)',
        () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));

      final stream = JalaGrpcInterceptor()
          .interceptStreaming<FakeMessage, FakeMessage>(
            fakeMethod<FakeMessage, FakeMessage>(),
            Stream<FakeMessage>.value(const FakeMessage(<String, Object?>{})),
            CallOptions(),
            streamingInvoker<FakeMessage, FakeMessage>(
              responses: <FakeMessage>[
                const FakeMessage(<String, Object?>{'r': 1}),
                const FakeMessage(<String, Object?>{'r': 2}),
              ],
            ),
          );
      final received = await stream.toList();
      await pump();

      // The app sees every message…
      expect(received, hasLength(2));
      // …but Jala records none of them, and says so with an empty body
      // rather than a misleading payload list.
      expect(onlyEntry.responseBody.kind, BodyKind.none);
      expect(onlyEntry.payloads, isEmpty);
    });

    test('the app keeps its single subscription to the response stream',
        () async {
      // Regression guard for the core constraint: tapping the response
      // stream would steal the app's only subscription.
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));

      final stream = JalaGrpcInterceptor()
          .interceptStreaming<FakeMessage, FakeMessage>(
            fakeMethod<FakeMessage, FakeMessage>(),
            Stream<FakeMessage>.value(const FakeMessage(<String, Object?>{})),
            CallOptions(),
            streamingInvoker<FakeMessage, FakeMessage>(
              responses: <FakeMessage>[
                const FakeMessage(<String, Object?>{'r': 1}),
              ],
            ),
          );

      expect(await stream.toList(), hasLength(1));
      await pump();
    });

    test('a failing stream is captured as an error', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));

      final stream = JalaGrpcInterceptor()
          .interceptStreaming<FakeMessage, FakeMessage>(
            fakeMethod<FakeMessage, FakeMessage>(),
            Stream<FakeMessage>.value(const FakeMessage(<String, Object?>{})),
            CallOptions(),
            streamingInvoker<FakeMessage, FakeMessage>(
              error: const GrpcError.unavailable('backend down'),
            ),
          );
      await expectLater(stream.toList(), throwsA(isA<GrpcError>()));
      await pump();

      final entry = onlyEntry;
      expect(entry.status, JalaCallStatus.error);
      expect(entry.grpcStatusCode, StatusCode.unavailable);
      expect(entry.errorMessage, contains('UNAVAILABLE'));
    });
  });

  group('redaction', () {
    test('masks secrets in a proto3-JSON message body', () async {
      // The regression 0.8.0 fixed: a decoded Map body used to bypass
      // redaction entirely, and proto3 JSON is exactly that shape.
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));

      await JalaGrpcInterceptor().interceptUnary<FakeMessage, FakeMessage>(
        fakeMethod<FakeMessage, FakeMessage>(),
        const FakeMessage(<String, Object?>{'password': 's3cret'}),
        CallOptions(),
        unaryInvoker<FakeMessage, FakeMessage>(
          response: const FakeMessage(<String, Object?>{
            'access_token': 'abc.def',
          }),
        ),
      );
      await pump();

      final entry = onlyEntry;
      expect(entry.requestBody.text, '{"password":"••••••"}');
      expect(entry.responseBody.text, '{"access_token":"••••••"}');
    });

    test('masks call metadata', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));

      await JalaGrpcInterceptor().interceptUnary<FakeMessage, FakeMessage>(
        fakeMethod<FakeMessage, FakeMessage>(),
        const FakeMessage(<String, Object?>{}),
        CallOptions(metadata: <String, String>{'authorization': 'Bearer xyz'}),
        unaryInvoker<FakeMessage, FakeMessage>(
          response: const FakeMessage(<String, Object?>{}),
        ),
      );
      await pump();

      expect(onlyEntry.requestHeaders['authorization'], JalaRedactor.mask);
    });
  });

  group('disabled binding', () {
    test('interceptUnary is a pure passthrough', () async {
      // No initialize() at all.
      late ResponseFuture<FakeMessage> produced;
      final inner = unaryInvoker<FakeMessage, FakeMessage>(
        response: const FakeMessage(<String, Object?>{'id': 1}),
      );

      final returned = JalaGrpcInterceptor()
          .interceptUnary<FakeMessage, FakeMessage>(
            fakeMethod<FakeMessage, FakeMessage>(),
            const FakeMessage(<String, Object?>{}),
            CallOptions(),
            (method, request, options) =>
                produced = inner(method, request, options),
          );

      expect(identical(returned, produced), isTrue);
      expect((await returned).fields['id'], 1);
      expect(JalaBinding.instance.isInitialized, isFalse);
    });

    test('an explicitly disabled config captures nothing', () async {
      JalaBinding.instance.initialize(config: JalaConfig());

      await JalaGrpcInterceptor().interceptUnary<FakeMessage, FakeMessage>(
        fakeMethod<FakeMessage, FakeMessage>(),
        const FakeMessage(<String, Object?>{}),
        CallOptions(),
        unaryInvoker<FakeMessage, FakeMessage>(
          response: const FakeMessage(<String, Object?>{}),
        ),
      );
      await pump();

      expect(JalaBinding.instance.store.entries, isEmpty);
    });
  });

  group('path parsing', () {
    test('splits a canonical gRPC path', () {
      expect(
        JalaGrpcInterceptor.serviceNameOf('/routeguide.RouteGuide/GetFeature'),
        'routeguide.RouteGuide',
      );
      expect(
        JalaGrpcInterceptor.methodNameOf('/routeguide.RouteGuide/GetFeature'),
        'GetFeature',
      );
    });

    test('degrades rather than throwing on an odd path', () {
      expect(JalaGrpcInterceptor.serviceNameOf('nonsense'), isNull);
      expect(JalaGrpcInterceptor.methodNameOf('nonsense'), 'nonsense');
      expect(JalaGrpcInterceptor.methodNameOf('/trailing/'), '/trailing/');
    });
  });

  group('wiring through Client (covers grpc-web)', () {
    // These exercise the *real* path a generated stub uses:
    // Client.$createUnaryCall builds the interceptor chain and then calls
    // channel.createCall(...). The tests above call interceptUnary /
    // interceptStreaming directly; these prove the interceptor is actually
    // reached when wired the way users wire it.
    //
    // Interceptors are applied by `Client`, *above* the channel, so this is
    // also the verification for gRPC-web: `GrpcWebClientChannel` is just
    // another `ClientChannelBase`, and nothing in the interceptor path knows
    // or cares which transport is underneath. The grpc-web transport itself
    // can't run here — `xhr_transport.dart` imports `dart:js_interop` and
    // `package:web`, so it does not load on the VM.

    test('a unary call through Client is captured', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeChannel channel = FakeChannel(
        response: const FakeMessage(<String, Object?>{'id': 7}),
        trailers: const <String, String>{'grpc-status': '0'},
      );
      final DemoClient client = DemoClient(
        channel,
        interceptors: <ClientInterceptor>[
          JalaGrpcInterceptor(endpoint: Uri.parse('grpc://api.example.com')),
        ],
      );

      final FakeMessage result = await client.unary(
        const FakeMessage(<String, Object?>{'name': 'ada'}),
      );
      expect(result.fields['id'], 7);
      await pump();

      expect(channel.calls, <String>['/routeguide.RouteGuide/GetFeature']);
      final NetworkCallEntry entry = onlyEntry;
      expect(entry.client, 'grpc');
      expect(entry.rpcKind, 'unary');
      expect(entry.operationName, 'GetFeature');
      expect(entry.grpcStatusCode, 0);
      expect(entry.requestBody.text, '{"name":"ada"}');
      expect(entry.responseBody.text, '{"id":7}');
    });

    test('a streaming call through Client is captured', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final DemoClient client = DemoClient(
        FakeChannel(
          response: const FakeMessage(<String, Object?>{'ack': true}),
          trailers: const <String, String>{'grpc-status': '0'},
        ),
        interceptors: <ClientInterceptor>[JalaGrpcInterceptor()],
      );

      await client
          .streaming(
            Stream<FakeMessage>.value(
              const FakeMessage(<String, Object?>{'msg': 'hi'}),
            ),
          )
          .toList();
      await pump();

      final NetworkCallEntry entry = onlyEntry;
      expect(entry.rpcKind, 'bidi');
      expect(entry.operationName, 'RouteChat');
      expect(entry.trailers['grpc-status'], '0');
    });

    test('a Client with no interceptors captures nothing', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final DemoClient client = DemoClient(
        FakeChannel(response: const FakeMessage(<String, Object?>{})),
      );

      await client.unary(const FakeMessage(<String, Object?>{}));
      await pump();

      // Guards against the capture coming from somewhere other than the
      // interceptor — e.g. a stray global hook.
      expect(JalaBinding.instance.store.entries, isEmpty);
    });

    test('a disabled binding leaves a Client call untouched', () async {
      final FakeChannel channel = FakeChannel(
        response: const FakeMessage(<String, Object?>{'id': 1}),
      );
      final DemoClient client = DemoClient(
        channel,
        interceptors: <ClientInterceptor>[JalaGrpcInterceptor()],
      );

      final FakeMessage result = await client.unary(
        const FakeMessage(<String, Object?>{}),
      );
      expect(result.fields['id'], 1);
      expect(JalaBinding.instance.isInitialized, isFalse);
    });
  });
}
