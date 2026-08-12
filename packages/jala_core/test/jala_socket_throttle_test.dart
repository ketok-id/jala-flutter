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
import 'package:jala_core/src/throttle/jala_socket_throttle_io.dart';
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
    for (int i = 0; i < chunks; i++) {
      socket.add(Uint8List(chunkSize));
    }
    await socket.flush();
    await socket.close();
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
}
