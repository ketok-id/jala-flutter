import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'jala_throttle_registry.dart';

/// A [Socket] decorator that paces real bytes through
/// [JalaThrottleRegistry.paceFor].
///
/// Unlike the adapter-level throttle, which delays an already-decoded
/// response body, this delays the bytes themselves — so a streamed download
/// genuinely arrives slowly and connection setup is not free. See
/// docs/plans/track-i-v0.8.3-socket-throttle.md.
///
/// **Transparency is the invariant.** With no active profile every member
/// must behave exactly as the wrapped socket does; Jala's standing promise
/// is that capture never breaks host networking, and this sits directly in
/// the host's data path. Extending [StreamView] rather than reimplementing
/// [Stream] keeps that surface small: [Stream]'s ~119 members come from the
/// base class, leaving only [IOSink] and [Socket]'s own members here.
class JalaThrottledSocket extends StreamView<Uint8List> implements Socket {
  /// Wraps [inner], pacing reads and writes per [registry].
  ///
  /// The mid-stream failure roll happens here, **once per connection** — see
  /// [JalaThrottleRegistry.midStreamFailureAt].
  factory JalaThrottledSocket(Socket inner, JalaThrottleRegistry registry) =>
      JalaThrottledSocket._(inner, registry, registry.midStreamFailureAt());

  JalaThrottledSocket._(
    Socket inner,
    JalaThrottleRegistry registry,
    int? failAt,
  ) : _inner = inner,
      _registry = registry,
      super(_pacedReads(inner, registry, failAt));

  final Socket _inner;
  final JalaThrottleRegistry _registry;

  /// The wrapped socket. Test-only: lets a test assert that direct HTTPS was
  /// actually secured, which is otherwise invisible from outside.
  Socket get innerForTesting => _inner;

  /// Serializes writes so each is delayed by its own transfer time without
  /// blocking [add], whose signature is synchronous.
  Future<void> _writes = Future<void>.value();

  /// First write error, surfaced from [flush] / [close] / [done] rather than
  /// escaping as an unhandled async error.
  Object? _writeError;
  StackTrace? _writeStack;

  /// Reads with real backpressure.
  ///
  /// The delay is computed from the chunk's own byte count, so total time is
  /// `bytes / rate` and nothing is hardcoded. Crucially the pacing is not
  /// merely cosmetic: `await for` **pauses its subscription while the loop
  /// body awaits**, so during each delay the socket is not drained, the OS
  /// receive buffer fills, the TCP window closes and the peer genuinely
  /// stops sending.
  ///
  /// That last point was verified rather than assumed — a test measures the
  /// time the *sender* takes to write 8 MiB and asserts it is blocked. An
  /// explicit `StreamController` with `pause`/`resume` was tried and behaves
  /// identically, so this simpler form is kept.
  static Stream<Uint8List> _pacedReads(
    Socket inner,
    JalaThrottleRegistry registry,
    int? failAt,
  ) async* {
    int seen = 0;
    await for (final Uint8List chunk in inner) {
      final Duration delay = registry.paceFor(
        chunk.length,
        registry.activeProfile?.downloadBytesPerSec,
      );
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      yield chunk;
      seen += chunk.length;

      // Bytes already delivered stay delivered — a connection dying
      // mid-transfer does not un-send what arrived, and the app's partial
      // handling is exactly what this is here to exercise.
      if (failAt != null && seen >= failAt) {
        inner.destroy();
        throw SocketException(
          'Jala throttle: connection dropped mid-stream by profile '
          '"${registry.activeProfile?.id ?? '?'}" after $seen bytes',
        );
      }
    }
  }

  void _enqueue(List<int> data) {
    _writes = _writes.then((_) async {
      if (_writeError != null) return;
      final Duration delay = _registry.paceFor(
        data.length,
        _registry.activeProfile?.uploadBytesPerSec,
      );
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      _inner.add(data);
    }).catchError((Object e, StackTrace st) {
      _writeError ??= e;
      _writeStack ??= st;
    });
  }

  Future<void> _drain() async {
    await _writes;
    final Object? e = _writeError;
    if (e != null) Error.throwWithStackTrace(e, _writeStack ?? StackTrace.current);
  }

  // ------------------------------------------------------------- IOSink

  @override
  Encoding get encoding => _inner.encoding;

  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  void add(List<int> data) => _enqueue(data);

  @override
  void write(Object? obj) {
    final String s = '$obj';
    if (s.isEmpty) return;
    _enqueue(encoding.encode(s));
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    final Iterator<dynamic> it = objects.iterator;
    if (!it.moveNext()) return;
    final StringBuffer buffer = StringBuffer();
    if (separator.isEmpty) {
      do {
        buffer.write(it.current);
      } while (it.moveNext());
    } else {
      buffer.write(it.current);
      while (it.moveNext()) {
        buffer
          ..write(separator)
          ..write(it.current);
      }
    }
    write(buffer.toString());
  }

  @override
  void writeln([Object? obj = '']) => write('$obj\n');

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await _drain();
    await for (final List<int> chunk in stream) {
      final Duration delay = _registry.paceFor(
        chunk.length,
        _registry.activeProfile?.uploadBytesPerSec,
      );
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      _inner.add(chunk);
    }
  }

  @override
  Future<void> flush() async {
    await _drain();
    await _inner.flush();
  }

  @override
  Future<void> close() async {
    await _drain();
    await _inner.close();
  }

  @override
  Future<void> get done => _writes.then((_) => _inner.done);

  // ------------------------------------------------------------- Socket

  @override
  void destroy() => _inner.destroy();

  @override
  bool setOption(SocketOption option, bool enabled) =>
      _inner.setOption(option, enabled);

  @override
  void setRawOption(RawSocketOption option) => _inner.setRawOption(option);

  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _inner.getRawOption(option);

  @override
  int get port => _inner.port;

  @override
  int get remotePort => _inner.remotePort;

  @override
  InternetAddress get address => _inner.address;

  @override
  InternetAddress get remoteAddress => _inner.remoteAddress;
}

/// Socket-level throttling entry points for `dart:io` platforms.
class JalaSocketThrottle {
  const JalaSocketThrottle._();

  /// Whether socket-level throttling can work on this platform.
  static bool get isSupported => true;

  /// A factory matching `HttpClient.connectionFactory`.
  ///
  /// Consults [registry] at connect time so a profile activated mid-session
  /// takes effect on the next connection, and applies, in order:
  ///
  /// 1. **Scope** — out-of-scope hosts get a plain, unwrapped connection, so
  ///    an unmatched host costs nothing at all.
  /// 2. **Drop** — a dropped connection fails as a real [SocketException]
  ///    rather than a synthetic error after the fact.
  /// 3. **Latency** — applied *before* connecting, so it behaves like RTT
  ///    instead of a delay on an already-established socket.
  /// 4. **Bandwidth** — the returned socket paces its own bytes.
  ///
  /// ## TLS is the factory's job
  ///
  /// Setting `connectionFactory` **disables `HttpClient`'s own TLS setup.**
  /// `_HttpClientConnection` only calls `SecureSocket.startConnect` on the
  /// branch where no factory is installed (`_http/http_impl.dart:2692`); with
  /// a factory it passes whatever socket you return straight through. Return
  /// a plain socket for an `https://` URL and the request goes out in
  /// cleartext, which the server answers by resetting the connection —
  /// observed on device as `HttpException: Connection reset by peer`.
  ///
  /// So this secures direct HTTPS itself. Proxied HTTPS is deliberately left
  /// plain, because `HttpClient` builds the CONNECT tunnel and secures it
  /// afterwards — mirroring the SDK's own
  /// `isSecure && proxy.isDirect` condition.
  ///
  /// **Known limitation:** a custom `SecurityContext` or
  /// `badCertificateCallback` on the host's `HttpClient` is not visible here
  /// and is therefore not applied. Apps relying on either should not enable
  /// socket throttling.
  static Future<ConnectionTask<Socket>> Function(Uri, String?, int?)
  connectionFactory(JalaThrottleRegistry registry) {
    return (Uri url, String? proxyHost, int? proxyPort) async {
      // Scope on the *target* host even when going through a proxy — the
      // user's glob is about the API they are testing, not the proxy.
      final bool inScope =
          registry.activeProfile != null && registry.hostMatches(url.host);
      final String host = proxyHost ?? url.host;
      final int port = proxyPort ?? _defaultPort(url);

      // Still TLS-aware: the factory is installed for *every* request, so
      // an out-of-scope host must get a correctly secured socket, just an
      // undecorated one. Returning a plain socket here broke every https
      // request in the app whether or not a profile was active.
      if (!inScope) {
        return _startConnect(
          url: url,
          host: host,
          port: port,
          proxied: proxyHost != null,
        );
      }

      if (registry.shouldDrop()) {
        throw SocketException(
          'Jala throttle: dropped by profile '
          '"${registry.activeProfile!.id}"',
          address: null,
          port: port,
        );
      }

      final Duration latency = registry.latencyFor();
      if (latency > Duration.zero) await Future<void>.delayed(latency);

      final ConnectionTask<Socket> task = await _startConnect(
        url: url,
        host: host,
        port: port,
        proxied: proxyHost != null,
      );
      return ConnectionTask.fromSocket<Socket>(
        task.socket.then<Socket>(
          (Socket socket) => JalaThrottledSocket(socket, registry),
        ),
        task.cancel,
      );
    };
  }

  /// Mirrors `HttpClient`'s own `isSecure && proxy.isDirect` choice, which a
  /// `connectionFactory` otherwise bypasses entirely.
  static Future<ConnectionTask<Socket>> _startConnect({
    required Uri url,
    required String host,
    required int port,
    required bool proxied,
  }) async {
    if (url.scheme == 'https' && !proxied) {
      final ConnectionTask<SecureSocket> secure =
          await SecureSocket.startConnect(host, port);
      return ConnectionTask.fromSocket<Socket>(secure.socket, secure.cancel);
    }
    return Socket.startConnect(host, port);
  }

  static int _defaultPort(Uri url) {
    if (url.hasPort) return url.port;
    return url.scheme == 'https' ? 443 : 80;
  }
}
