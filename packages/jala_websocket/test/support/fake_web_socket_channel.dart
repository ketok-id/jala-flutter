import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A test double for [WebSocketChannel] built on top of a [StreamChannel]
/// (typically the `foreign` side of a `StreamChannelController`), so tests
/// can drive a simulated live connection without any real network I/O.
///
/// [closeCode]/[closeReason] are plain mutable fields rather than being
/// derived automatically, mirroring how a real `WebSocketChannel`
/// implementation updates them from the underlying transport whenever it
/// closes — tests set them directly to simulate that.
class FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  FakeWebSocketChannel(this._channel, {Future<void>? ready, this.protocol})
    : ready = ready ?? Future<void>.value() {
    _sink = _FakeWebSocketSink(
      _channel.sink,
      onClose: (int? code, String? reason) {
        closeCode = code;
        closeReason = reason;
      },
    );
  }

  final StreamChannel<dynamic> _channel;

  @override
  final Future<void> ready;

  @override
  final String? protocol;

  @override
  int? closeCode;

  @override
  String? closeReason;

  // Closing is the test's/app's responsibility, not this fake's — see the
  // matching note on `JalaWebSocketChannel._sink`.
  // ignore: close_sinks
  late final WebSocketSink _sink;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  WebSocketSink get sink => _sink;
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._inner, {required this.onClose});

  final StreamSink<dynamic> _inner;
  final void Function(int? code, String? reason) onClose;

  @override
  Future<dynamic> get done => _inner.done;

  @override
  void add(dynamic data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) =>
      _inner.addStream(stream);

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) {
    onClose(closeCode, closeReason);
    return _inner.close();
  }
}

/// A [Pattern] whose matching always throws, used to force a deliberate
/// failure inside `JalaRedactor.redactBody` (and therefore `WsFrame.capture`)
/// so tests can verify capture bugs never break the app's WebSocket stream.
class ThrowingPattern implements Pattern {
  @override
  Iterable<Match> allMatches(String string, [int start = 0]) {
    throw StateError('boom: redaction pattern failure');
  }

  @override
  Match? matchAsPrefix(String string, [int start = 0]) {
    throw StateError('boom: redaction pattern failure');
  }
}
