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

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!JalaBinding.instance.isEnabled) {
      handler.next(options);
      return;
    }
    try {
      _captureRequest(options);
    } catch (_) {
      // A capture bug must never break the app's networking.
    }
    handler.next(options);
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
    try {
      _captureError(err);
    } catch (_) {
      // A capture bug must never break the app's networking.
    }
    handler.next(err);
  }

  void _captureRequest(RequestOptions options) {
    final JalaBinding binding = JalaBinding.instance;
    final String id = JalaIdGenerator.next();
    options.extra[idExtraKey] = id;
    options.extra[startExtraKey] = Stopwatch()..start();

    final Map<String, String> rawHeaders = <String, String>{
      for (final MapEntry<String, dynamic> entry in options.headers.entries)
        entry.key: '${entry.value}',
    };
    final Map<String, String> headers = binding.config.redactor.redactHeaders(
      rawHeaders,
    );

    final _BodyCapture capture = _captureRequestBody(
      options.data,
      contentType: options.contentType,
      maxBytes: binding.config.maxBodyBytes,
      redactor: binding.config.redactor,
    );

    final String? replayOf = options.extra[replayOfExtraKey] as String?;

    binding.bus.emit(
      NetworkRequestEvent(
        callId: id,
        timestamp: DateTime.now(),
        method: options.method.toUpperCase(),
        uri: options.uri,
        headers: headers,
        body: capture.body,
        size: capture.size,
        client: 'dio',
        replayOf: replayOf,
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
      final Map<String, dynamic> summary = _summarizeFormData(data);
      final CapturedBody body = _redactedCapture(
        summary,
        contentType: 'application/json',
        maxBytes: maxBytes,
        redactor: redactor,
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

  Map<String, dynamic> _summarizeFormData(FormData data) {
    return <String, dynamic>{
      'fields': <Map<String, String>>[
        for (final MapEntry<String, String> entry in data.fields)
          <String, String>{'name': entry.key, 'value': entry.value},
      ],
      'files': <Map<String, dynamic>>[
        for (final MapEntry<String, MultipartFile> entry in data.files)
          <String, dynamic>{
            'field': entry.key,
            'filename': entry.value.filename,
            'length': entry.value.length,
          },
      ],
    };
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
