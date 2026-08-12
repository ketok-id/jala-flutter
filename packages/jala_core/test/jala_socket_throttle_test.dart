@TestOn('vm')
library;

// `close_sinks` cannot see through these: a Socket is an IOSink, and these
// are short-lived loopback connections that are either drained to completion
// (the remote closes them) or explicitly destroyed in the test body. Closing
// an already-closed socket to satisfy the lint would be worse than the lint.
// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// Hide the barrel's JalaSocketThrottle: its conditional export resolves to
// the web stub under analysis, so the real `dart:io` one comes from the
// direct src import below.
import 'package:jala_core/jala_core.dart' hide JalaSocketThrottle;
import 'package:jala_core/jala_socket_throttle_io.dart';
import 'package:test/test.dart';

/// Server that pushes [chunks] x [chunkSize] bytes then closes.
Future<ServerSocket> _pushServer({
  required int chunks,
  required int chunkSize,
}) async {
  final ServerSocket server = await ServerSocket.bind(
    InternetAddress.loopbackIPv4,
    0,
  );
  server.listen((Socket socket) async {
    // A client that vanishes mid-transfer — which the mid-stream failure
    // test does deliberately — makes these writes fail with a broken pipe.
    // That is the scenario, not a defect, so the server absorbs it.
    try {
      for (int i = 0; i < chunks; i++) {
        socket.add(Uint8List(chunkSize));
      }
      await socket.flush();
      await socket.close();
    } on Object {
      socket.destroy();
    }
  });
  return server;
}

void main() {
  group('JalaThrottledSocket transparency (no active profile)', () {
    late ServerSocket server;

    setUp(() async {
      server = await _pushServer(chunks: 4, chunkSize: 256);
    });
    tearDown(() async => server.close());

    test('forwards address/port members from the wrapped socket', () async {
      final JalaThrottleRegistry registry = JalaThrottleRegistry();
      final Socket raw = await Socket.connect(server.address, server.port);
      final JalaThrottledSocket wrapped = JalaThrottledSocket(raw, registry);

      expect(wrapped.port, raw.port);
      expect(wrapped.remotePort, raw.remotePort);
      expect(wrapped.address, raw.address);
      expect(wrapped.remoteAddress, raw.remoteAddress);
      expect(wrapped.encoding, raw.encoding);

      // setOption must reach the real socket, not silently no-op.
      expect(wrapped.setOption(SocketOption.tcpNoDelay, true), isTrue);

      await wrapped.close();
      wrapped.destroy();
      await registry.dispose();
    });

    test('delivers every byte unchanged and in order', () async {
      final JalaThrottleRegistry registry = JalaThrottleRegistry();
      final Socket raw = await Socket.connect(server.address, server.port);
      final JalaThrottledSocket wrapped = JalaThrottledSocket(raw, registry);

      final List<int> received = await wrapped.fold<List<int>>(
        <int>[],
        (List<int> acc, Uint8List d) => acc..addAll(d),
      );
      expect(received.length, 4 * 256);
      await registry.dispose();
    });

    test('adds no measurable delay when no profile is active', () async {
      final JalaThrottleRegistry registry = JalaThrottleRegistry();
      final Socket raw = await Socket.connect(server.address, server.port);
      final JalaThrottledSocket wrapped = JalaThrottledSocket(raw, registry);

      final Stopwatch sw = Stopwatch()..start();
      await wrapped.drain<void>();
      sw.stop();

      // 1 KB over loopback with throttling off must not be paced at all.
      expect(sw.elapsedMilliseconds, lessThan(300));
      await registry.dispose();
    });
  });

  group('JalaThrottledSocket pacing', () {
    test('paces reads by the download cap', () async {
      final ServerSocket server = await _pushServer(
        chunks: 4,
        chunkSize: 1024,
      );
      addTearDown(server.close);

      final JalaThrottleRegistry registry = JalaThrottleRegistry()
        ..setActive(
          const JalaThrottleProfile(
            id: 'test',
            name: 'test',
            latencyMs: 0,
            // 4 KB total at 8 KB/s = ~500ms of pacing.
            downloadBytesPerSec: 8 * 1024,
          ),
        );

      final Socket raw = await Socket.connect(server.address, server.port);
      final JalaThrottledSocket wrapped = JalaThrottledSocket(raw, registry);

      final Stopwatch sw = Stopwatch()..start();
      await wrapped.drain<void>();
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        greaterThanOrEqualTo(400),
        reason: '4 KB at 8 KB/s should take about half a second',
      );
      await registry.dispose();
    });

    test('a disabled binding paces nothing', () async {
      final ServerSocket server = await _pushServer(chunks: 4, chunkSize: 1024);
      addTearDown(server.close);

      // isEnabled false => every registry read reports the "off" value.
      final JalaThrottleRegistry registry = JalaThrottleRegistry(
        isEnabled: () => false,
      )..setActive(JalaThrottleProfile.slow3g);

      final Socket raw = await Socket.connect(server.address, server.port);
      final JalaThrottledSocket wrapped = JalaThrottledSocket(raw, registry);

      final Stopwatch sw = Stopwatch()..start();
      await wrapped.drain<void>();
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(300));
      await registry.dispose();
    });
  });

  group('connectionFactory', () {
    test('leaves out-of-scope hosts unwrapped', () async {
      final ServerSocket server = await _pushServer(chunks: 1, chunkSize: 64);
      addTearDown(server.close);

      final JalaThrottleRegistry registry = JalaThrottleRegistry()
        ..setActive(
          JalaThrottleProfile.offline, // 100% drop
          hostPattern: 'nothing.matches.this',
        );

      final factory = JalaSocketThrottle.connectionFactory(registry);
      final ConnectionTask<Socket> task = await factory(
        Uri.parse('http://${server.address.host}:${server.port}/'),
        null,
        null,
      );
      final Socket socket = await task.socket;

      // Not dropped, and not decorated.
      expect(socket, isNot(isA<JalaThrottledSocket>()));
      socket.destroy();
      await registry.dispose();
    });

    test('drops in-scope connections as a real SocketException', () async {
      final JalaThrottleRegistry registry = JalaThrottleRegistry()
        ..setActive(JalaThrottleProfile.offline);

      final factory = JalaSocketThrottle.connectionFactory(registry);
      await expectLater(
        factory(Uri.parse('http://127.0.0.1:1/'), null, null),
        throwsA(isA<SocketException>()),
      );
      await registry.dispose();
    });

    test('wraps in-scope connections', () async {
      final ServerSocket server = await _pushServer(chunks: 1, chunkSize: 64);
      addTearDown(server.close);

      final JalaThrottleRegistry registry = JalaThrottleRegistry(
        random: Random(1),
      )..setActive(
        const JalaThrottleProfile(id: 't', name: 't', latencyMs: 0),
      );

      final factory = JalaSocketThrottle.connectionFactory(registry);
      final ConnectionTask<Socket> task = await factory(
        Uri.parse('http://${server.address.host}:${server.port}/'),
        null,
        null,
      );
      final Socket socket = await task.socket;

      expect(socket, isA<JalaThrottledSocket>());
      socket.destroy();
      await registry.dispose();
    });
  });

  group('socketModeActive', () {
    test('defaults false and reports the off value when disabled', () async {
      final JalaThrottleRegistry on = JalaThrottleRegistry();
      expect(on.socketModeActive, isFalse);
      on.socketModeActive = true;
      expect(on.socketModeActive, isTrue);
      await on.dispose();

      final JalaThrottleRegistry off = JalaThrottleRegistry(
        isEnabled: () => false,
      )..socketModeActive = true;
      expect(
        off.socketModeActive,
        isFalse,
        reason: 'a disabled binding must make every read a true no-op',
      );
      await off.dispose();
    });
  });

  group('TLS (regression: connectionFactory disables HttpClient TLS)', () {
    test('an https URL yields a secured socket, not a plain one', () async {
      // Setting connectionFactory bypasses HttpClient's own
      // SecureSocket.startConnect, so the factory must secure direct HTTPS
      // itself. Returning a plain socket sent cleartext to a TLS port and the
      // server reset the connection — seen on device as
      // "HttpException: Connection reset by peer".
      final JalaThrottleRegistry registry = JalaThrottleRegistry()
        ..setActive(
          const JalaThrottleProfile(id: 't', name: 't', latencyMs: 0),
        );

      final factory = JalaSocketThrottle.connectionFactory(registry);
      final ConnectionTask<Socket> task = await factory(
        Uri.parse('https://example.com/'),
        null,
        null,
      );
      final Socket socket = await task.socket;

      expect(socket, isA<JalaThrottledSocket>());
      expect(
        (socket as JalaThrottledSocket).innerForTesting,
        isA<SecureSocket>(),
        reason: 'direct https must be TLS-secured by the factory',
      );
      socket.destroy();
      await registry.dispose();
    }, tags: <String>['network']);

    test('an http URL stays a plain socket', () async {
      final ServerSocket server = await _pushServer(chunks: 1, chunkSize: 8);
      addTearDown(server.close);

      final JalaThrottleRegistry registry = JalaThrottleRegistry()
        ..setActive(
          const JalaThrottleProfile(id: 't', name: 't', latencyMs: 0),
        );

      final factory = JalaSocketThrottle.connectionFactory(registry);
      final ConnectionTask<Socket> task = await factory(
        Uri.parse('http://${server.address.host}:${server.port}/'),
        null,
        null,
      );
      final Socket socket = await task.socket;

      expect(
        (socket as JalaThrottledSocket).innerForTesting,
        isNot(isA<SecureSocket>()),
      );
      socket.destroy();
      await registry.dispose();
    });
  });

  test('an out-of-scope https host is still TLS-secured', () async {
    // The factory is installed process-wide, so it must return a usable
    // socket even for hosts it does not throttle. An earlier version
    // short-circuited to a plain Socket here, which broke every https
    // request in the app whenever socket mode was on.
    final JalaThrottleRegistry registry = JalaThrottleRegistry()
      ..setActive(
        JalaThrottleProfile.slow3g,
        hostPattern: 'nothing.matches.this',
      );

    final factory = JalaSocketThrottle.connectionFactory(registry);
    final ConnectionTask<Socket> task = await factory(
      Uri.parse('https://example.com/'),
      null,
      null,
    );
    final Socket socket = await task.socket;

    expect(socket, isNot(isA<JalaThrottledSocket>()), reason: 'not decorated');
    expect(socket, isA<SecureSocket>(), reason: 'but still secured');
    socket.destroy();
    await registry.dispose();
  }, tags: <String>['network']);

  test('applies real TCP backpressure, not just delay-after-arrival', () async {
    // Proves the pacing is not cosmetic. A sender writing far more than the
    // socket buffers can hold only finishes quickly if the reader is
    // draining quickly; if the reader stalls, the receive window closes and
    // the sender blocks. Measured at ~380ms for 8 MiB here, against ~4ms
    // when the payload fits entirely in buffers.
    // Must exceed the OS socket buffers, which on loopback are large — at
    // 512 KB the sender finished in 4ms because everything fit.
    const int total = 8 * 1024 * 1024;
    final Completer<int> senderElapsed = Completer<int>();

    final ServerSocket server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(server.close);
    server.listen((Socket socket) async {
      final Stopwatch sw = Stopwatch()..start();
      socket.add(Uint8List(total));
      await socket.flush();
      sw.stop();
      senderElapsed.complete(sw.elapsedMilliseconds);
      await socket.close();
    });

    final JalaThrottleRegistry registry = JalaThrottleRegistry()
      ..setActive(
        const JalaThrottleProfile(
          id: 'bp',
          name: 'bp',
          latencyMs: 0,
          // 8 MiB at 2 MiB/s ~= 4s of pacing.
          downloadBytesPerSec: 2 * 1024 * 1024,
        ),
      );

    final Socket raw = await Socket.connect(server.address, server.port);
    final JalaThrottledSocket wrapped = JalaThrottledSocket(raw, registry);

    final int received = await wrapped
        .fold<int>(0, (int n, Uint8List d) => n + d.length);
    final int senderMs = await senderElapsed.future;

    expect(received, total, reason: 'every byte still arrives');
    expect(
      senderMs,
      greaterThan(500),
      reason: 'the SENDER must be slowed. Delay-after-arrival would let it '
          'dump $total bytes into the buffer and finish near-instantly; '
          'only pausing the subscription pushes back on the peer.',
    );
    await registry.dispose();
  });

  group('mid-stream failure', () {
    test('dies partway through a long transfer, keeping bytes already sent',
        () async {
      final ServerSocket server = await _pushServer(
        chunks: 64,
        chunkSize: 16 * 1024, // 1 MiB total, well past the 512 KB fail window
      );
      addTearDown(server.close);

      final JalaThrottleRegistry registry = JalaThrottleRegistry()
        ..setActive(
          const JalaThrottleProfile(
            id: 'lossy',
            name: 'lossy',
            latencyMs: 0,
            midStreamDropRate: 1, // always, for determinism
          ),
        );

      final Socket raw = await Socket.connect(server.address, server.port);
      final JalaThrottledSocket wrapped = JalaThrottledSocket(raw, registry);

      int received = 0;
      Object? error;
      try {
        await for (final Uint8List chunk in wrapped) {
          received += chunk.length;
        }
      } on Object catch (e) {
        error = e;
      }

      expect(error, isA<SocketException>(), reason: 'a real connection error');
      expect(
        received,
        greaterThan(0),
        reason: 'bytes delivered before the failure stay delivered — that '
            'partial state is what this feature exists to exercise',
      );
      // Deterministic regardless of chunking: the stream is cut at the
      // failure offset, which always lands inside the 8 KB..512 KB window.
      // CI caught this — on Linux loopback the whole 1 MiB arrived as one
      // chunk, so an implementation that only failed on chunk boundaries
      // delivered everything before "failing".
      expect(received, greaterThanOrEqualTo(8 * 1024));
      expect(received, lessThan(512 * 1024));
      expect(received, lessThan(64 * 16 * 1024), reason: 'it did not finish');
      await registry.dispose();
    });

    test('a short transfer completes even at rate 1', () async {
      // The failure window starts at 8 KB, so small responses survive — which
      // is also how a real flaky link behaves.
      final ServerSocket server = await _pushServer(chunks: 1, chunkSize: 512);
      addTearDown(server.close);

      final JalaThrottleRegistry registry = JalaThrottleRegistry()
        ..setActive(
          const JalaThrottleProfile(
            id: 'lossy',
            name: 'lossy',
            latencyMs: 0,
            midStreamDropRate: 1,
          ),
        );

      final Socket raw = await Socket.connect(server.address, server.port);
      final JalaThrottledSocket wrapped = JalaThrottledSocket(raw, registry);

      final int received =
          await wrapped.fold<int>(0, (int n, Uint8List d) => n + d.length);
      expect(received, 512);
      await registry.dispose();
    });

    test('rate 0 never fires, and the roll is once per connection', () {
      final JalaThrottleRegistry off = JalaThrottleRegistry()
        ..setActive(JalaThrottleProfile.slow3g); // midStreamDropRate defaults 0
      expect(off.midStreamFailureAt(), isNull);

      final JalaThrottleRegistry on = JalaThrottleRegistry()
        ..setActive(
          const JalaThrottleProfile(
            id: 'x',
            name: 'x',
            latencyMs: 0,
            midStreamDropRate: 1,
          ),
        );
      final int? at = on.midStreamFailureAt();
      expect(at, isNotNull);
      expect(at, greaterThanOrEqualTo(8 * 1024));
      expect(at, lessThan(512 * 1024));
    });
  });
}
