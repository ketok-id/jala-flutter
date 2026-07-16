import 'dart:async';
import 'dart:typed_data';

import 'package:jala_core/jala_core.dart';
import 'package:jala_websocket/jala_websocket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'support/fake_web_socket_channel.dart';

/// Flushes pending microtasks so async event-bus deliveries (and `ready`
/// future completions) settle.
Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  tearDown(JalaBinding.resetForTesting);

  /// Wires up an enabled `JalaBinding` and a connected pair: [server] is the
  /// test's view of "the other end of the wire" (what a real server would
  /// see/send), and [wrapped] is the `JalaWebSocketChannel` the app would
  /// use, backed by a [FakeWebSocketChannel].
  ({StreamChannel<dynamic> server, WebSocketChannel wrapped, FakeWebSocketChannel fake})
  connect({
    JalaConfig? config,
    Uri? uri,
    Future<void>? ready,
  }) {
    JalaBinding.instance.initialize(
      config: config ?? JalaConfig(enabled: true),
    );
    final StreamChannelController<dynamic> controller =
        StreamChannelController<dynamic>();
    final FakeWebSocketChannel fake = FakeWebSocketChannel(
      controller.foreign,
      ready: ready,
    );
    final WebSocketChannel wrapped = JalaWebSocketChannel.wrap(
      fake,
      uri: uri ?? Uri.parse('wss://example.dev/socket'),
    );
    return (server: controller.local, wrapped: wrapped, fake: fake);
  }

  group('connect and open', () {
    test(
      'wrap emits a connect event immediately, before ready resolves; '
      'open follows once ready completes',
      () async {
        final readyCompleter = Completer<void>();
        final conn = connect(ready: readyCompleter.future);
        final sub = conn.wrapped.stream.listen((_) {});
        addTearDown(sub.cancel);
        await pump();

        final entries = JalaBinding.instance.store.wsConnections;
        expect(entries, hasLength(1));
        final connecting = entries.single;
        expect(connecting.uri, Uri.parse('wss://example.dev/socket'));
        expect(connecting.status, WsConnectionStatus.connecting);

        readyCompleter.complete();
        await pump();

        expect(
          JalaBinding.instance.store.wsConnections.single.status,
          WsConnectionStatus.open,
        );
      },
    );

    test('a ready error does not emit an open event', () async {
      final conn = connect(
        ready: Future<void>.error(StateError('handshake failed')),
      );
      // Ignore the unhandled ready error at the call site the same way a
      // real app's `channel.ready` would need to be handled independently.
      unawaited(conn.wrapped.ready.catchError((_) {}));
      unawaited(conn.wrapped.stream.drain<void>().catchError((_) {}));
      await pump();
      await pump();

      final entry = JalaBinding.instance.store.wsConnections.single;
      expect(entry.status, WsConnectionStatus.connecting);
    });
  });

  group('frame capture', () {
    test('received text frame is captured with direction/size', () async {
      final conn = connect();
      final received = <dynamic>[];
      final sub = conn.wrapped.stream.listen(received.add);
      addTearDown(sub.cancel);

      conn.server.sink.add('hello');
      await pump();

      expect(received, ['hello']);
      final entry = JalaBinding.instance.store.wsConnections.single;
      expect(entry.frameCount, 1);
      final frame = entry.frames.single;
      expect(frame.direction, WsDirection.received);
      expect(frame.isBinary, isFalse);
      expect(frame.size, 5);
      expect(frame.preview, 'hello');
    });

    test('sent text frame is captured with direction/size', () async {
      final conn = connect();
      final sub = conn.wrapped.stream.listen((_) {});
      addTearDown(sub.cancel);
      final serverReceived = <dynamic>[];
      final serverSub = conn.server.stream.listen(serverReceived.add);
      addTearDown(serverSub.cancel);

      conn.wrapped.sink.add('hi there');
      await pump();

      expect(serverReceived, ['hi there']);
      final entry = JalaBinding.instance.store.wsConnections.single;
      expect(entry.frameCount, 1);
      final frame = entry.frames.single;
      expect(frame.direction, WsDirection.sent);
      expect(frame.size, 8);
      expect(frame.preview, 'hi there');
    });

    test('binary frames are captured as metadata-only (no preview)', () async {
      final conn = connect();
      final received = <dynamic>[];
      final sub = conn.wrapped.stream.listen(received.add);
      addTearDown(sub.cancel);

      final Uint8List bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      conn.server.sink.add(bytes);
      await pump();

      expect(received, hasLength(1));
      final entry = JalaBinding.instance.store.wsConnections.single;
      final frame = entry.frames.single;
      expect(frame.isBinary, isTrue);
      expect(frame.size, 5);
      expect(frame.preview, isNull);
    });

    test('app still receives frames if capture throws', () async {
      final conn = connect(
        config: JalaConfig(
          enabled: true,
          redactor: JalaRedactor(redactedBodyPatterns: [ThrowingPattern()]),
        ),
      );
      final received = <dynamic>[];
      final sub = conn.wrapped.stream.listen(received.add);
      addTearDown(sub.cancel);

      conn.server.sink.add('this would normally be redacted');
      await pump();

      // The app-visible stream must still deliver the frame untouched.
      expect(received, ['this would normally be redacted']);
      // But capture itself failed, so no frame landed in the store.
      final entry = JalaBinding.instance.store.wsConnections.single;
      expect(entry.frameCount, 0);
      expect(entry.frames, isEmpty);
    });

    test('frame text is redacted before being stored', () async {
      final conn = connect(
        config: JalaConfig(
          enabled: true,
          redactor: JalaRedactor(redactedBodyPatterns: [RegExp('secret-\\w+')]),
        ),
      );
      final received = <dynamic>[];
      final sub = conn.wrapped.stream.listen(received.add);
      addTearDown(sub.cancel);

      conn.server.sink.add('token=secret-abc123');
      await pump();

      // App still sees the raw, unredacted payload.
      expect(received, ['token=secret-abc123']);
      final frame = JalaBinding.instance.store.wsConnections.single.frames
          .single;
      expect(frame.preview, 'token=${JalaRedactor.mask}');
    });
  });

  group('ring buffer overflow', () {
    test('older frames are evicted once the per-connection cap is hit', () async {
      final conn = connect(
        config: JalaConfig(enabled: true, maxWsFramesPerConnection: 2),
      );
      final sub = conn.wrapped.stream.listen((_) {});
      addTearDown(sub.cancel);

      conn.server.sink.add('one');
      conn.server.sink.add('two');
      conn.server.sink.add('three');
      await pump();

      final entry = JalaBinding.instance.store.wsConnections.single;
      expect(entry.frameCount, 3, reason: 'total ever observed');
      expect(entry.frames, hasLength(2), reason: 'ring buffer cap');
      expect(entry.frames.map((f) => f.preview), ['two', 'three']);
    });
  });

  group('close', () {
    test('app-initiated sink.close captures code/reason immediately', () async {
      final conn = connect();
      final sub = conn.wrapped.stream.listen((_) {});
      addTearDown(sub.cancel);
      // Closing wrapped.sink ultimately closes the underlying transport's
      // stream too (WebSocketChannel's close-causes-stream-to-close
      // guarantee) — something must drain the "other end" so close()'s
      // returned future can actually complete.
      final serverSub = conn.server.stream.listen((_) {});
      addTearDown(serverSub.cancel);

      await conn.wrapped.sink.close(1000, 'bye');
      await pump();

      final entry = JalaBinding.instance.store.wsConnections.single;
      expect(entry.status, WsConnectionStatus.closed);
      expect(entry.closeCode, 1000);
      expect(entry.closeReason, 'bye');
    });

    test(
      'server-initiated close is captured from the inner channel close code',
      () async {
        final conn = connect();
        final sub = conn.wrapped.stream.listen((_) {});
        addTearDown(sub.cancel);

        // Simulate the underlying transport recording a close code/reason
        // before the stream reports done, matching how a real
        // WebSocketChannel behaves.
        conn.fake.closeCode = 1001;
        conn.fake.closeReason = 'server going away';
        await conn.server.sink.close();
        await pump();

        final entry = JalaBinding.instance.store.wsConnections.single;
        expect(entry.status, WsConnectionStatus.closed);
        expect(entry.closeCode, 1001);
        expect(entry.closeReason, 'server going away');
      },
    );

    test(
      'a close triggered by the app does not double-emit once the '
      'stream subsequently completes',
      () async {
        final conn = connect();
        final events = <WsConnectionStatus>[];
        final storeSub = JalaBinding.instance.store.watchWs.listen((list) {
          if (list.isNotEmpty) events.add(list.single.status);
        });
        addTearDown(storeSub.cancel);
        final sub = conn.wrapped.stream.listen((_) {});
        addTearDown(sub.cancel);
        final serverSub = conn.server.stream.listen((_) {});
        addTearDown(serverSub.cancel);

        await conn.wrapped.sink.close(1000, 'done');
        await conn.server.sink.close();
        await pump();

        final entry = JalaBinding.instance.store.wsConnections.single;
        expect(entry.status, WsConnectionStatus.closed);
        expect(entry.closeCode, 1000);
        expect(entry.closeReason, 'done');
      },
    );
  });

  group('error', () {
    test('a stream error is captured as a WsErrorEvent', () async {
      final conn = connect();
      final errors = <Object>[];
      final sub = conn.wrapped.stream.listen(
        (_) {},
        onError: errors.add,
      );
      addTearDown(sub.cancel);

      conn.server.sink.addError(StateError('connection reset'));
      await pump();

      expect(errors, hasLength(1));
      final entry = JalaBinding.instance.store.wsConnections.single;
      expect(entry.status, WsConnectionStatus.error);
      expect(entry.closeReason, contains('connection reset'));
    });
  });

  group('disabled binding', () {
    test('wrap returns the exact same channel instance untouched', () {
      // No JalaBinding.instance.initialize() call: disabled by default.
      final StreamChannelController<dynamic> controller =
          StreamChannelController<dynamic>();
      final FakeWebSocketChannel fake = FakeWebSocketChannel(
        controller.foreign,
      );

      final WebSocketChannel result = JalaWebSocketChannel.wrap(
        fake,
        uri: Uri.parse('wss://example.dev/socket'),
      );

      expect(identical(result, fake), isTrue);
    });

    test('explicitly disabled config is also a zero-cost passthrough', () {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: false));
      final StreamChannelController<dynamic> controller =
          StreamChannelController<dynamic>();
      final FakeWebSocketChannel fake = FakeWebSocketChannel(
        controller.foreign,
      );

      final WebSocketChannel result = JalaWebSocketChannel.wrap(fake);

      expect(identical(result, fake), isTrue);
      expect(JalaBinding.instance.store.wsConnections, isEmpty);
    });
  });
}
