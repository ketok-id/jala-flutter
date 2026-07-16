import 'dart:async';

import 'package:jala_core/jala_core.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Wraps a [WebSocketChannel] so every frame sent or received, plus the
/// connection's open/close/error lifecycle, is captured into
/// `JalaBinding.instance` — see [wrap].
///
/// Reads global bindings via [JalaBinding.instance] instead of taking
/// constructor parameters, matching `jala_http`'s `JalaHttpClient` and
/// `jala_dio`'s `JalaDioInterceptor` — a single `Jala.initialize()` call in
/// the app configures every attached client/channel.
///
/// A bug in the capture logic itself must never break the app's WebSocket
/// traffic: every capture call site is wrapped in `try`/`catch`, and the
/// original data/error/done event is always forwarded to the app exactly
/// once regardless of whether capture succeeded.
class JalaWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  JalaWebSocketChannel._(this._inner, this._connectionId, this._binding) {
    _stream = _inner.stream.transform(
      StreamTransformer<dynamic, dynamic>.fromHandlers(
        handleData: _handleData,
        handleError: _handleError,
        handleDone: _handleDone,
      ),
    );
    _sink = _CapturingWebSocketSink(
      _inner.sink,
      onAdd: _handleSent,
      onClose: _handleSinkClose,
    );
  }

  /// Wraps [channel] so its traffic is captured into
  /// `JalaBinding.instance`.
  ///
  /// [uri] should be the URI [channel] was connected with —
  /// `WebSocketChannel` has no way to report its own URL (see the class
  /// docs on `WebSocketChannel.connect`), so pass it explicitly (the same
  /// `Uri` given to `WebSocketChannel.connect`, or your own channel's URL)
  /// for a meaningful connection entry in the inspector. When omitted, a
  /// placeholder `unknown://unknown` URI is captured instead.
  ///
  /// A [WsConnectEvent] is emitted immediately (synchronously, before this
  /// returns); once [channel]'s `ready` future completes successfully, a
  /// [WsOpenEvent] follows. If `ready` completes with an error, no
  /// [WsOpenEvent] is emitted — the stream's error handler already reports
  /// a [WsErrorEvent] for a failed handshake, so the `ready` error itself
  /// is ignored here to avoid double-reporting.
  ///
  /// When Jala is disabled (or `Jala.initialize()` was never called), this
  /// returns [channel] completely untouched — the same object, not a
  /// wrapper — so wrapping is zero-cost and safe to leave in release
  /// builds.
  static WebSocketChannel wrap(WebSocketChannel channel, {Uri? uri}) {
    final JalaBinding binding = JalaBinding.instance;
    if (!binding.isEnabled) return channel;

    final String connectionId = JalaIdGenerator.next();
    final Uri effectiveUri =
        uri ?? Uri(scheme: 'unknown', host: 'unknown');

    try {
      binding.bus.emit(
        WsConnectEvent(
          connectionId: connectionId,
          timestamp: DateTime.now(),
          uri: effectiveUri,
        ),
      );
    } catch (_) {
      // A capture bug must never prevent the channel from being usable.
    }

    final JalaWebSocketChannel wrapped = JalaWebSocketChannel._(
      channel,
      connectionId,
      binding,
    );

    unawaited(
      channel.ready.then(
        (_) {
          if (!binding.isEnabled) return;
          try {
            binding.bus.emit(
              WsOpenEvent(connectionId: connectionId, timestamp: DateTime.now()),
            );
          } catch (_) {
            // A capture bug must never break the app's WebSocket traffic.
          }
        },
        onError: (Object _, StackTrace _) {
          // Ignored: the stream's error handler already emits a
          // WsErrorEvent for a failed handshake — see _handleError.
        },
      ),
    );

    return wrapped;
  }

  final WebSocketChannel _inner;
  final String _connectionId;
  final JalaBinding _binding;

  /// Guards against emitting more than one terminal event (close or error)
  /// for the same connection — e.g. the app calling `sink.close()` and the
  /// inner stream subsequently completing as a direct consequence of that
  /// close should only ever produce a single close event, and an error
  /// that also ends the stream should not additionally be reported as a
  /// close.
  bool _terminalEmitted = false;

  late final Stream<dynamic> _stream;
  // This wraps `_inner.sink`, which the app owns and is responsible for
  // closing (or the app may never close it at all, e.g. it's still open
  // when the app exits) — mirrors the WebSocketChannel contract itself,
  // which never closes its own sink implicitly either. `close()` delegates
  // to `_inner.sink.close()`, so nothing is silently leaked here.
  // ignore: close_sinks
  late final WebSocketSink _sink;

  @override
  String? get protocol => _inner.protocol;

  @override
  int? get closeCode => _inner.closeCode;

  @override
  String? get closeReason => _inner.closeReason;

  @override
  Future<void> get ready => _inner.ready;

  @override
  Stream<dynamic> get stream => _stream;

  @override
  WebSocketSink get sink => _sink;

  void _handleData(dynamic data, EventSink<dynamic> sink) {
    _captureFrame(WsDirection.received, data);
    sink.add(data);
  }

  void _handleError(
    Object error,
    StackTrace stackTrace,
    EventSink<dynamic> sink,
  ) {
    _emitTerminal(
      () => WsErrorEvent(
        connectionId: _connectionId,
        timestamp: DateTime.now(),
        errorMessage: error.toString(),
      ),
    );
    sink.addError(error, stackTrace);
  }

  void _handleDone(EventSink<dynamic> sink) {
    _emitTerminal(
      () => WsCloseEvent(
        connectionId: _connectionId,
        timestamp: DateTime.now(),
        code: _inner.closeCode,
        reason: _inner.closeReason,
      ),
    );
    sink.close();
  }

  void _handleSent(dynamic data) {
    _captureFrame(WsDirection.sent, data);
  }

  void _handleSinkClose(int? code, String? reason) {
    _emitTerminal(
      () => WsCloseEvent(
        connectionId: _connectionId,
        timestamp: DateTime.now(),
        code: code,
        reason: reason,
      ),
    );
  }

  void _captureFrame(WsDirection direction, dynamic data) {
    if (!_binding.isEnabled) return;
    try {
      final WsFrame frame = WsFrame.capture(
        timestamp: DateTime.now(),
        direction: direction,
        data: data,
        redactor: _binding.config.redactor,
      );
      _binding.bus.emit(
        WsFrameEvent(
          connectionId: _connectionId,
          timestamp: frame.timestamp,
          frame: frame,
        ),
      );
    } catch (_) {
      // A capture bug must never break the app's WebSocket traffic.
    }
  }

  void _emitTerminal(JalaEvent Function() build) {
    if (_terminalEmitted) return;
    _terminalEmitted = true;
    if (!_binding.isEnabled) return;
    try {
      _binding.bus.emit(build());
    } catch (_) {
      // A capture bug must never break the app's WebSocket traffic.
    }
  }
}

/// [WebSocketSink] wrapper that reports every [add] and [close] call to
/// [onAdd]/[onClose] before delegating to [_inner].
///
/// [onAdd] and [onClose] are expected to handle their own errors — mirrors
/// [JalaWebSocketChannel]'s "capture must never break the app" rule, so this
/// class itself does not add a redundant `try`/`catch` around each callback.
class _CapturingWebSocketSink implements WebSocketSink {
  _CapturingWebSocketSink(
    this._inner, {
    required this.onAdd,
    required this.onClose,
  });

  final WebSocketSink _inner;
  final void Function(dynamic data) onAdd;
  final void Function(int? closeCode, String? closeReason) onClose;

  @override
  Future<dynamic> get done => _inner.done;

  @override
  void add(dynamic data) {
    onAdd(data);
    _inner.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _inner.addError(error, stackTrace);
  }

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) => _inner.addStream(stream);

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) {
    onClose(closeCode, closeReason);
    return _inner.close(closeCode, closeReason);
  }
}
