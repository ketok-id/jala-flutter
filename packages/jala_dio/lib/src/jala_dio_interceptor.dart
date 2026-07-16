import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:jala_core/jala_core.dart';

/// Dio interceptor that captures every request, response, error, and
/// cancellation into `JalaBinding.instance`'s store.
///
/// Reads global bindings via [JalaBinding.instance] instead of taking
/// constructor parameters, so a single `Jala.initialize()` call in the app
/// configures every attached [JalaDioInterceptor]. Before Jala is
/// initialized (or when disabled by config), every hook is a synchronous,
/// zero-capture forward — the first line of each hook checks
/// [JalaBinding.isEnabled] and, if false, immediately forwards without
/// doing any capture work.
///
/// A bug in the capture logic itself must never break the host app's
/// networking: every hook wraps its capture work in `try`/`catch` and always
/// forwards the request/response/error to the next interceptor exactly
/// once, regardless of whether capture succeeded.
class JalaDioInterceptor extends Interceptor {
  /// Creates the interceptor. Safe to construct before
  /// `Jala.initialize()` — [JalaBinding.instance] is only read inside the
  /// hooks, and only once [JalaBinding.isEnabled] is true.
  JalaDioInterceptor();

  /// `RequestOptions.extra` key holding this call's Jala id.
  ///
  /// SPEC-NOTE: exposed as a public constant (rather than kept private) so
  /// `JalaDioReplayer` and tests can read/write it without string
  /// duplication.
  static const String idExtraKey = 'jala_id';

  /// `RequestOptions.extra` key holding the running [Stopwatch] used to
  /// measure call duration.
  static const String startExtraKey = 'jala_start';

  /// `RequestOptions.extra` key a replaying client sets to the id of the
  /// original call, read back in [onRequest] to populate
  /// `NetworkRequestEvent.replayOf`.
  static const String replayOfExtraKey = 'jala_replay_of';

  /// When true, response/error capture was already emitted by the mock
  /// short-circuit path — [onResponse]/[onError] must not double-capture.
  static const String mockHandledExtraKey = 'jala_mock_handled';

  /// `RequestOptions.extra` key holding this call's shared [_ProgressState],
  /// created in [_captureRequest] and read back in [_captureResponse] so
  /// upload- and download-side byte counts are reported together on the
  /// same [NetworkProgressEvent] — see B4 in docs/plans/track-b-v0.2.md.
  static const String _progressStateExtraKey = 'jala_progress_state';

  /// Cadence for [NetworkProgressEvent] emission on either side of a call:
  /// every ~64 KB transferred, plus unconditionally on the first and last
  /// chunk of whichever side an interceptor can actually observe.
  ///
  /// SPEC-NOTE: unlike `jala_http` (a real client wrapper that sees every
  /// request/response byte), an interceptor only ever observes bytes for
  /// the two cases below — everything else (the common case: `Map`/`bytes`/
  /// `FormData` request bodies, and any non-streamed response) resolves
  /// synchronously inside Dio's own transformer before the interceptor gets
  /// a look, so no progress is ever emitted for it and pending entries keep
  /// the plain spinner. This is a documented limitation, not a bug:
  ///  - Download progress is only observable when the caller opts into
  ///    `ResponseType.stream` (so `response.data` is Dio's own
  ///    `ResponseBody`, whose `.stream` this interceptor can re-wrap).
  ///  - Upload progress is only observable when the caller passes a
  ///    `Stream<List<int>>` directly as `RequestOptions.data` (Dio's own
  ///    supported way to stream a request body) — `FormData`/`Map`/bytes
  ///    bodies are converted to bytes by Dio's transformer, off of a stream
  ///    this interceptor never sees.
  static const int _progressThresholdBytes = 64 * 1024;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!JalaBinding.instance.isEnabled) {
      handler.next(options);
      return;
    }

    _BodyCapture? bodyCapture;
    try {
      bodyCapture = _prepareRequest(options);
    } catch (_) {
      // A capture bug must never break the app's networking.
      handler.next(options);
      return;
    }

    final JalaBinding binding = JalaBinding.instance;
    final JalaMockRule? rule = binding.mockRegistry.match(
      method: options.method.toUpperCase(),
      uri: options.uri,
      bodyText: bodyCapture.body.text,
    );

    try {
      _emitRequest(options, bodyCapture, mockRuleId: rule?.id);
    } catch (_) {
      // Continue even if emit fails.
    }

    if (rule == null) {
      handler.next(options);
      return;
    }

    unawaited(_applyMock(rule, options, handler));
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (!JalaBinding.instance.isEnabled) {
      handler.next(response);
      return;
    }
    if (response.requestOptions.extra[mockHandledExtraKey] == true) {
      handler.next(response);
      return;
    }
    try {
      _captureResponse(response);
    } catch (_) {
      // A capture bug must never break the app's networking.
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!JalaBinding.instance.isEnabled) {
      handler.next(err);
      return;
    }
    if (err.requestOptions.extra[mockHandledExtraKey] == true) {
      handler.next(err);
      return;
    }
    try {
      _captureError(err);
    } catch (_) {
      // A capture bug must never break the app's networking.
    }
    handler.next(err);
  }

  /// Allocates call id / stopwatch / progress wrappers and returns the
  /// captured request body (for mock matching) without emitting yet.
  _BodyCapture _prepareRequest(RequestOptions options) {
    final JalaBinding binding = JalaBinding.instance;
    final String id = JalaIdGenerator.next();
    options.extra[idExtraKey] = id;
    options.extra[startExtraKey] = Stopwatch()..start();

    final _BodyCapture capture = _captureRequestBody(
      options.data,
      contentType: options.contentType,
      maxBytes: binding.config.maxBodyBytes,
      redactor: binding.config.redactor,
    );

    final _ProgressState progressState = _ProgressState()
      ..sentTotal = _headerInt(options.headers, Headers.contentLengthHeader);
    options.extra[_progressStateExtraKey] = progressState;
    if (options.data is Stream) {
      options.data = _wrapUploadStream(
        options.data as Stream<dynamic>,
        callId: id,
        binding: binding,
        state: progressState,
      );
    }
    return capture;
  }

  void _emitRequest(
    RequestOptions options,
    _BodyCapture capture, {
    String? mockRuleId,
  }) {
    final JalaBinding binding = JalaBinding.instance;
    final Map<String, String> rawHeaders = <String, String>{
      for (final MapEntry<String, dynamic> entry in options.headers.entries)
        entry.key: '${entry.value}',
    };
    final Map<String, String> headers = binding.config.redactor.redactHeaders(
      rawHeaders,
    );
    final String? replayOf = options.extra[replayOfExtraKey] as String?;

    binding.bus.emit(
      NetworkRequestEvent(
        callId: options.extra[idExtraKey] as String,
        timestamp: DateTime.now(),
        method: options.method.toUpperCase(),
        uri: options.uri,
        headers: headers,
        body: capture.body,
        size: capture.size,
        client: 'dio',
        replayOf: replayOf,
        mockRuleId: mockRuleId,
      ),
    );
  }

  Future<void> _applyMock(
    JalaMockRule rule,
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final Duration? delay = rule.action.delay;
      if (delay != null && delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      switch (rule.action) {
        case final MockDelay _:
          handler.next(options);
        case final MockResponse action:
          options.extra[mockHandledExtraKey] = true;
          final Stopwatch? stopwatch =
              options.extra[startExtraKey] as Stopwatch?;
          final Duration duration = stopwatch?.elapsed ?? Duration.zero;
          final List<int> bytes = utf8.encode(action.body);
          final dynamic data = _mockResponseData(options, action, bytes);
          final Headers headers = Headers.fromMap(<String, List<String>>{
            for (final MapEntry<String, String> e in action.headers.entries)
              e.key: <String>[e.value],
          });
          final Response<dynamic> response = Response<dynamic>(
            requestOptions: options,
            statusCode: action.statusCode,
            statusMessage: null,
            headers: headers,
            data: data,
          );
          try {
            _emitMockResponse(
              options: options,
              statusCode: action.statusCode,
              headers: action.headers,
              body: action.body,
              size: bytes.length,
              duration: duration,
            );
          } catch (_) {}
          handler.resolve(response, true);
        case final MockFailure action:
          options.extra[mockHandledExtraKey] = true;
          final Stopwatch? stopwatch =
              options.extra[startExtraKey] as Stopwatch?;
          final DioException err = _mockFailureException(options, action);
          try {
            JalaBinding.instance.bus.emit(
              NetworkErrorEvent(
                callId: options.extra[idExtraKey] as String,
                timestamp: DateTime.now(),
                errorMessage: err.message ?? err.toString(),
                duration: stopwatch?.elapsed,
              ),
            );
          } catch (_) {}
          handler.reject(err);
      }
    } catch (_) {
      // If mock application fails, fall through to the real network.
      handler.next(options);
    }
  }

  dynamic _mockResponseData(
    RequestOptions options,
    MockResponse action,
    List<int> bytes,
  ) {
    switch (options.responseType) {
      case ResponseType.bytes:
        return Uint8List.fromList(bytes);
      case ResponseType.stream:
        return ResponseBody.fromBytes(
          bytes,
          action.statusCode,
          headers: <String, List<String>>{
            for (final MapEntry<String, String> e in action.headers.entries)
              e.key: <String>[e.value],
          },
        );
      case ResponseType.plain:
        return action.body;
      case ResponseType.json:
        try {
          return jsonDecode(action.body);
        } on Object {
          return action.body;
        }
    }
  }

  DioException _mockFailureException(
    RequestOptions options,
    MockFailure action,
  ) {
    switch (action.kind) {
      case MockFailureKind.timeout:
        return DioException.connectionTimeout(
          timeout: options.connectTimeout ?? const Duration(seconds: 0),
          requestOptions: options,
        );
      case MockFailureKind.connectionError:
        return DioException.connectionError(
          requestOptions: options,
          reason: 'Jala mock connection error',
        );
    }
  }

  void _emitMockResponse({
    required RequestOptions options,
    required int statusCode,
    required Map<String, String> headers,
    required String body,
    required int size,
    required Duration duration,
  }) {
    final JalaBinding binding = JalaBinding.instance;
    final String id = options.extra[idExtraKey] as String;
    final CapturedBody captured = CapturedBody.capture(
      body,
      contentType: headers.entries
          .where((MapEntry<String, String> e) =>
              e.key.toLowerCase() == 'content-type')
          .map((MapEntry<String, String> e) => e.value)
          .firstOrNull,
      maxBytes: binding.config.maxBodyBytes,
    );
    binding.bus.emit(
      NetworkResponseEvent(
        callId: id,
        timestamp: DateTime.now(),
        statusCode: statusCode,
        headers: binding.config.redactor.redactHeaders(headers),
        body: captured,
        size: size,
        duration: duration,
      ),
    );
  }

  void _captureResponse(Response<dynamic> response) {
    final JalaBinding binding = JalaBinding.instance;
    final RequestOptions options = response.requestOptions;
    final String? id = options.extra[idExtraKey] as String?;
    if (id == null) {
      // Never captured on the way out (e.g. Jala was disabled during
      // onRequest); there is nothing to correlate this response with.
      return;
    }
    final Stopwatch? stopwatch = options.extra[startExtraKey] as Stopwatch?;

    final _ProgressState? progressState =
        options.extra[_progressStateExtraKey] as _ProgressState?;
    if (progressState != null && options.responseType == ResponseType.stream) {
      _wireDownloadProgress(
        response,
        callId: id,
        binding: binding,
        state: progressState,
      );
    }

    final Map<String, String> headers = binding.config.redactor.redactHeaders(
      _flattenHeaders(response.headers),
    );

    final _BodyCapture capture = _captureResponseBody(
      response.data,
      responseType: options.responseType,
      contentType: _headerValue(response.headers, Headers.contentTypeHeader),
      maxBytes: binding.config.maxBodyBytes,
      redactor: binding.config.redactor,
    );

    binding.bus.emit(
      NetworkResponseEvent(
        callId: id,
        timestamp: DateTime.now(),
        // SPEC-NOTE: `NetworkResponseEvent.statusCode` is non-nullable, but
        // `Response.statusCode` is nullable (it is only null for manually
        // constructed responses, never for a real network round-trip); 0
        // is used as a defensive fallback that should never be observed in
        // practice.
        statusCode: response.statusCode ?? 0,
        statusMessage: response.statusMessage,
        headers: headers,
        body: capture.body,
        size: capture.size,
        duration: stopwatch?.elapsed ?? Duration.zero,
      ),
    );
  }

  void _captureError(DioException err) {
    final JalaBinding binding = JalaBinding.instance;
    final RequestOptions options = err.requestOptions;
    final String? id = options.extra[idExtraKey] as String?;
    if (id == null) return;
    final Stopwatch? stopwatch = options.extra[startExtraKey] as Stopwatch?;

    if (err.type == DioExceptionType.cancel) {
      binding.bus.emit(
        NetworkCancelEvent(callId: id, timestamp: DateTime.now()),
      );
      return;
    }

    final Response<dynamic>? response = err.response;
    Map<String, String>? headers;
    CapturedBody? body;
    if (response != null) {
      headers = binding.config.redactor.redactHeaders(
        _flattenHeaders(response.headers),
      );
      body = _captureResponseBody(
        response.data,
        responseType: options.responseType,
        contentType: _headerValue(response.headers, Headers.contentTypeHeader),
        maxBytes: binding.config.maxBodyBytes,
        redactor: binding.config.redactor,
      ).body;
    }

    binding.bus.emit(
      NetworkErrorEvent(
        callId: id,
        timestamp: DateTime.now(),
        errorMessage: err.message ?? err.toString(),
        statusCode: response?.statusCode,
        headers: headers,
        body: body,
        duration: stopwatch?.elapsed,
      ),
    );
  }

  _BodyCapture _captureRequestBody(
    dynamic data, {
    required String? contentType,
    required int maxBytes,
    required JalaRedactor redactor,
  }) {
    if (data is FormData) {
      final List<JalaMultipartPart> parts = _multipartParts(data);
      final CapturedBody body = CapturedBodyMultipart.capture(
        parts,
        maxBytes: maxBytes,
      );
      return _BodyCapture(body, data.length);
    }
    final CapturedBody body = _redactedCapture(
      data,
      contentType: contentType,
      maxBytes: maxBytes,
      redactor: redactor,
    );
    return _BodyCapture(body, body.originalSize);
  }

  _BodyCapture _captureResponseBody(
    dynamic data, {
    required ResponseType responseType,
    required String? contentType,
    required int maxBytes,
    required JalaRedactor redactor,
  }) {
    // SPEC-NOTE: `ResponseType.stream`/`bytes` are metadata-only per spec —
    // Jala never decodes or retains the actual bytes for these response
    // types, regardless of the reported content-type.
    if (responseType == ResponseType.stream) {
      final CapturedBody body = CapturedBody.capture(
        const Stream<List<int>>.empty(),
      );
      return _BodyCapture(body, null);
    }
    if (responseType == ResponseType.bytes) {
      // SPEC-NOTE: unlike the metadata-only default below, image bytes
      // within cap are retained (as `BodyKind.image`) when
      // `JalaConfig.captureImageBodies` is enabled — see B2 in
      // docs/plans/track-b-v0.2.md. Every other content-type keeps the
      // original behavior: metadata only, regardless of what the header
      // reports. `data` is only ever something other than `List<int>` for
      // a malformed/manually-built response, which the original code also
      // didn't special-case — fall back to the pre-image-preview capture
      // path so that stays true.
      if (data is List<int>) {
        final CapturedBody body = CapturedBody.captureBytes(
          data,
          contentType: contentType,
          maxBytes: maxBytes,
          captureImages: JalaBinding.instance.config.captureImageBodies,
        );
        return _BodyCapture(body, body.originalSize);
      }
      final CapturedBody body = CapturedBody.capture(data, maxBytes: maxBytes);
      return _BodyCapture(body, body.originalSize);
    }
    final CapturedBody body = _redactedCapture(
      data,
      contentType: contentType,
      maxBytes: maxBytes,
      redactor: redactor,
    );
    return _BodyCapture(body, body.originalSize);
  }

  CapturedBody _redactedCapture(
    dynamic data, {
    required String? contentType,
    required int maxBytes,
    required JalaRedactor redactor,
  }) {
    // SPEC-NOTE: `JalaRedactor.redactedBodyPatterns` (empty by default) is
    // applied only to already-`String` bodies, *before* capture. This keeps
    // `CapturedBody.truncated`/`originalSize` correct for the common case
    // without needing to reconstruct a `CapturedBody` after the fact (its
    // fields cannot be set independently post-capture — only produced via
    // `CapturedBody.capture`). Non-string bodies (Map/List/bytes) are
    // captured as-is; only header redaction applies to them.
    final dynamic redactable = data is String
        ? redactor.redactBody(data)
        : data;
    return CapturedBody.capture(
      redactable,
      contentType: contentType,
      maxBytes: maxBytes,
    );
  }

  List<JalaMultipartPart> _multipartParts(FormData data) {
    return <JalaMultipartPart>[
      for (final MapEntry<String, String> entry in data.fields)
        JalaMultipartPart(
          name: entry.key,
          size: utf8.encode(entry.value).length,
        ),
      for (final MapEntry<String, MultipartFile> entry in data.files)
        JalaMultipartPart(
          name: entry.key,
          filename: entry.value.filename,
          contentType: entry.value.contentType?.mimeType,
          size: entry.value.length,
        ),
    ];
  }

  /// Wraps a caller-supplied `Stream<List<int>>` request body (Dio's own
  /// supported way to stream an upload) so upload progress can be observed
  /// — see [_progressThresholdBytes]'s SPEC-NOTE for why this is the only
  /// upload shape an interceptor can instrument.
  Stream<List<int>> _wrapUploadStream(
    Stream<dynamic> data, {
    required String callId,
    required JalaBinding binding,
    required _ProgressState state,
  }) {
    final Stream<List<int>> source = data.cast<List<int>>();
    int sent = 0;
    int lastEmittedAt = 0;
    return source.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (List<int> chunk, EventSink<List<int>> sink) {
          sent += chunk.length;
          state.sentBytes = sent;
          if (lastEmittedAt == 0 ||
              sent - lastEmittedAt >= _progressThresholdBytes) {
            lastEmittedAt = sent;
            _emitProgress(binding, callId, state);
          }
          sink.add(chunk);
        },
        handleDone: (EventSink<List<int>> sink) {
          state.sentBytes = sent;
          _emitProgress(binding, callId, state);
          sink.close();
        },
      ),
    );
  }

  /// Re-wraps a `ResponseType.stream` response's [ResponseBody.stream] so
  /// download progress can be observed, replacing it in place — the caller
  /// still reads `response.data.stream` (a [ResponseBody]) exactly as
  /// before, just with a progress-emitting layer in front of it.
  void _wireDownloadProgress(
    Response<dynamic> response, {
    required String callId,
    required JalaBinding binding,
    required _ProgressState state,
  }) {
    final dynamic data = response.data;
    if (data is! ResponseBody) return;
    state.receivedTotal ??= _headerValueInt(
      response.headers,
      Headers.contentLengthHeader,
    );
    int received = 0;
    int lastEmittedAt = 0;
    data.stream = data.stream.transform(
      StreamTransformer<Uint8List, Uint8List>.fromHandlers(
        handleData: (Uint8List chunk, EventSink<Uint8List> sink) {
          received += chunk.length;
          state.receivedBytes = received;
          if (lastEmittedAt == 0 ||
              received - lastEmittedAt >= _progressThresholdBytes) {
            lastEmittedAt = received;
            _emitProgress(binding, callId, state);
          }
          sink.add(chunk);
        },
        handleDone: (EventSink<Uint8List> sink) {
          state.receivedBytes = received;
          _emitProgress(binding, callId, state);
          sink.close();
        },
      ),
    );
  }

  void _emitProgress(JalaBinding binding, String callId, _ProgressState state) {
    try {
      binding.bus.emit(
        NetworkProgressEvent(
          callId: callId,
          timestamp: DateTime.now(),
          sentBytes: state.sentBytes,
          sentTotal: state.sentTotal,
          receivedBytes: state.receivedBytes,
          receivedTotal: state.receivedTotal,
        ),
      );
    } catch (_) {
      // A capture bug must never break the app's networking.
    }
  }

  int? _headerInt(Map<String, dynamic> headers, String name) {
    for (final MapEntry<String, dynamic> entry in headers.entries) {
      if (entry.key.toLowerCase() == name) {
        return int.tryParse('${entry.value}');
      }
    }
    return null;
  }

  int? _headerValueInt(Headers headers, String name) {
    final String? value = _headerValue(headers, name);
    return value == null ? null : int.tryParse(value);
  }

  Map<String, String> _flattenHeaders(Headers headers) {
    final Map<String, String> result = <String, String>{};
    headers.forEach((String name, List<String> values) {
      result[name] = values.join(', ');
    });
    return result;
  }

  String? _headerValue(Headers headers, String name) {
    final List<String>? values = headers[name];
    if (values == null || values.isEmpty) return null;
    return values.join(', ');
  }
}

/// Pairs a captured body with its best-effort original size in bytes.
class _BodyCapture {
  const _BodyCapture(this.body, this.size);

  final CapturedBody body;
  final int? size;
}

/// Mutable, per-call running totals shared between [JalaDioInterceptor
/// ._captureRequest] (upload side) and [JalaDioInterceptor._captureResponse]
/// (download side), so every emitted [NetworkProgressEvent] reports both
/// sides' latest known values together rather than one side clobbering the
/// other's last-known figure.
class _ProgressState {
  int sentBytes = 0;
  int? sentTotal;
  int receivedBytes = 0;
  int? receivedTotal;
}
