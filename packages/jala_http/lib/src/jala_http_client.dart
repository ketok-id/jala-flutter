import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:jala_core/jala_core.dart';

/// [http.BaseClient] wrapper that captures every request, response, and
/// error made through [inner] into `JalaBinding.instance`, and supports
/// one-tap replay via `JalaHttpReplayer`.
///
/// Reads global bindings via [JalaBinding.instance] instead of taking
/// constructor parameters — matching `jala_dio`'s `JalaDioInterceptor` —
/// so a single `Jala.initialize()` call in the app configures every
/// [JalaHttpClient]. Before Jala is initialized (or when disabled by
/// config), [send] is a synchronous, zero-capture passthrough to [inner]:
/// the first line checks [JalaBinding.isEnabled] and, if false, forwards
/// immediately without doing any capture work.
///
/// A bug in the capture logic itself must never break the host app's
/// networking: request-side capture is wrapped in `try`/`catch` and always
/// forwards the request to [inner] regardless of whether capture
/// succeeded; response-body capture runs inside the stream tee (see
/// [_teeAndCapture]) behind its own `try`/`catch`, so it can never corrupt
/// or block the stream the caller actually reads.
///
/// Prefer `JalaHttp.wrap(...)`, which constructs this and registers a
/// `JalaHttpReplayer` with `JalaBinding.instance.replayRegistry` in one
/// call.
class JalaHttpClient extends http.BaseClient {
  /// Creates a client wrapping [inner] (a fresh `http.Client()` when
  /// omitted).
  JalaHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// Request header a replaying client sets to the id of the original
  /// call; read back — and stripped before the request is actually sent —
  /// in [send], to populate `NetworkRequestEvent.replayOf`.
  ///
  /// SPEC-NOTE: `http.BaseRequest` has no equivalent of Dio's
  /// `RequestOptions.extra` bag, so a header is the least intrusive place
  /// to stash replay metadata. `JalaHttpReplayer` is the only intended
  /// writer of this header, and [send] always removes it from the request
  /// before it reaches [inner] (and the real network), so it never leaks
  /// to the server or shows up in captured headers.
  static const String replayOfHeader = 'x-jala-replay-of';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final JalaBinding binding = JalaBinding.instance;
    if (!binding.isEnabled) {
      return _inner.send(request);
    }

    String? id;
    Stopwatch? stopwatch;
    try {
      final _RequestCapture capture = _captureRequest(request, binding);
      id = capture.id;
      stopwatch = capture.stopwatch;
    } catch (_) {
      // A capture bug must never break the app's networking; fall back to
      // an uncaptured passthrough for this call.
    }

    if (id == null) {
      return _inner.send(request);
    }
    final String callId = id;

    try {
      final http.StreamedResponse response = await _inner.send(request);
      return _captureResponse(
        response,
        callId: callId,
        stopwatch: stopwatch,
        binding: binding,
      );
    } catch (error) {
      try {
        binding.bus.emit(
          NetworkErrorEvent(
            callId: callId,
            timestamp: DateTime.now(),
            errorMessage: error.toString(),
            duration: stopwatch?.elapsed,
          ),
        );
      } catch (_) {
        // A capture bug must never break the app's networking.
      }
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
  }

  _RequestCapture _captureRequest(
    http.BaseRequest request,
    JalaBinding binding,
  ) {
    final String id = JalaIdGenerator.next();
    final Stopwatch stopwatch = Stopwatch()..start();

    final String? replayOf = request.headers[replayOfHeader];
    if (replayOf != null) {
      request.headers.remove(replayOfHeader);
    }

    final Map<String, String> headers = binding.config.redactor.redactHeaders(
      request.headers,
    );

    final _BodyCapture bodyCapture = _captureRequestBody(
      request,
      maxBytes: binding.config.maxBodyBytes,
    );

    binding.bus.emit(
      NetworkRequestEvent(
        callId: id,
        timestamp: DateTime.now(),
        method: request.method.toUpperCase(),
        uri: request.url,
        headers: headers,
        body: bodyCapture.body,
        size: bodyCapture.size,
        client: 'http',
        replayOf: replayOf,
      ),
    );

    return _RequestCapture(id: id, stopwatch: stopwatch);
  }

  _BodyCapture _captureRequestBody(
    http.BaseRequest request, {
    required int maxBytes,
  }) {
    if (request is http.MultipartRequest) {
      final Map<String, dynamic> summary = <String, dynamic>{
        'fields': <Map<String, String>>[
          for (final MapEntry<String, String> entry in request.fields.entries)
            <String, String>{'name': entry.key, 'value': entry.value},
        ],
        'files': <Map<String, dynamic>>[
          for (final http.MultipartFile file in request.files)
            <String, dynamic>{
              'field': file.field,
              'filename': file.filename,
              'length': file.length,
            },
        ],
      };
      final CapturedBody body = CapturedBody.capture(
        summary,
        contentType: 'application/json',
        maxBytes: maxBytes,
      );
      return _BodyCapture(body, request.contentLength);
    }

    if (request is http.StreamedRequest) {
      // Metadata only: the request body is a caller-driven sink that Jala
      // must never consume — doing so would break the actual upload.
      final CapturedBody body = CapturedBody.capture(
        const Stream<List<int>>.empty(),
      );
      return _BodyCapture(body, request.contentLength);
    }

    if (request is http.Request) {
      final List<int> bytes = request.bodyBytes;
      if (bytes.isEmpty) {
        return const _BodyCapture(CapturedBody.none, null);
      }
      final String? contentType = _headerValue(
        request.headers,
        'content-type',
      );
      final CapturedBody body = CapturedBody.capture(
        bytes,
        contentType: contentType,
        maxBytes: maxBytes,
      );
      return _BodyCapture(body, body.originalSize);
    }

    // Unknown BaseRequest subtype: be conservative and capture nothing
    // rather than guessing at its shape.
    return const _BodyCapture(CapturedBody.none, null);
  }

  http.StreamedResponse _captureResponse(
    http.StreamedResponse response, {
    required String callId,
    required Stopwatch? stopwatch,
    required JalaBinding binding,
  }) {
    final int maxBytes = binding.config.maxBodyBytes;
    final String? contentType = _headerValue(response.headers, 'content-type');

    final Stream<List<int>> teed = _teeAndCapture(
      response.stream,
      maxBytes: maxBytes,
      onDone: (List<int> buffered, int totalLength, bool truncated) {
        try {
          final CapturedBody body = _buildResponseBody(
            buffered,
            contentType: contentType,
            maxBytes: maxBytes,
            truncated: truncated,
          );
          final Map<String, String> headers = binding.config.redactor
              .redactHeaders(response.headers);
          binding.bus.emit(
            NetworkResponseEvent(
              callId: callId,
              timestamp: DateTime.now(),
              statusCode: response.statusCode,
              statusMessage: response.reasonPhrase,
              headers: headers,
              body: body,
              size: totalLength,
              duration: stopwatch?.elapsed ?? Duration.zero,
            ),
          );
        } catch (_) {
          // A capture bug must never break the app's networking.
        }
      },
      onError: (Object error) {
        try {
          binding.bus.emit(
            NetworkErrorEvent(
              callId: callId,
              timestamp: DateTime.now(),
              errorMessage: error.toString(),
              statusCode: response.statusCode,
              duration: stopwatch?.elapsed,
            ),
          );
        } catch (_) {
          // A capture bug must never break the app's networking.
        }
      },
    );

    return http.StreamedResponse(
      teed,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  CapturedBody _buildResponseBody(
    List<int> buffered, {
    required String? contentType,
    required int maxBytes,
    required bool truncated,
  }) {
    if (!truncated) {
      // The buffer holds the entire body (the stream never exceeded the
      // cap): a plain capture() call already reports the correct
      // kind/size/truncated triple.
      return CapturedBody.capture(
        buffered,
        contentType: contentType,
        maxBytes: maxBytes,
      );
    }
    // The true body exceeded [maxBytes], but Jala only ever buffered up to
    // [maxBytes] real bytes of it (see [_teeAndCapture]) — deliberately
    // never the full body. Asking `capture()` to treat that bounded buffer
    // as one byte over its *own* length deterministically produces
    // `BodyKind.truncated` from real captured content, rather than relying
    // on `capture()`'s internal encode/decode round-trip to happen to
    // exceed [maxBytes] on its own.
    //
    // SPEC-NOTE: `CapturedBody.originalSize` in this branch reflects the
    // size of the bounded buffer (~[maxBytes]), not the true full body
    // size — `jala_core`'s public API has no way to report a virtual
    // "original size" larger than the content it's handed without either
    // materializing the full body (defeating the point of the cap) or
    // faking element data (unsafe: `capture()` decodes textual bodies in
    // full before truncating, so a fake byte list would transiently
    // allocate a string as large as the fake length). The true total size
    // is instead carried accurately by `NetworkResponseEvent.size` /
    // `NetworkCallEntry.responseSize`, which this adapter always sets from
    // its own byte counter — see the `totalLength` argument to `onDone`.
    final int forcedCap = buffered.isEmpty ? 0 : buffered.length - 1;
    return CapturedBody.capture(
      buffered,
      contentType: contentType,
      maxBytes: forcedCap,
    );
  }

  String? _headerValue(Map<String, String> headers, String name) {
    final String lower = name.toLowerCase();
    for (final MapEntry<String, String> entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }
}

/// Tees [source] into a new stream that forwards every chunk to the
/// caller unmodified, while separately buffering at most [maxBytes] of it
/// for capture and counting the true total length.
///
/// [source] is only subscribed to once the returned stream is listened to,
/// mirroring normal `Stream` semantics. [onDone] fires exactly once, with
/// the buffered prefix (never larger than [maxBytes]), the true total byte
/// count, and whether the stream exceeded [maxBytes] (and was therefore
/// only partially buffered). [onError] fires (in addition to the error
/// being forwarded to the caller) if [source] errors before completing.
Stream<List<int>> _teeAndCapture(
  Stream<List<int>> source, {
  required int maxBytes,
  required void Function(List<int> buffered, int totalLength, bool truncated)
  onDone,
  required void Function(Object error) onError,
}) {
  late final StreamController<List<int>> controller;
  StreamSubscription<List<int>>? subscription;
  final BytesBuilder builder = BytesBuilder();
  int total = 0;
  bool finished = false;

  void finish() {
    if (finished) return;
    finished = true;
    onDone(builder.takeBytes(), total, total > maxBytes);
  }

  controller = StreamController<List<int>>(
    onListen: () {
      subscription = source.listen(
        (List<int> chunk) {
          total += chunk.length;
          final int room = maxBytes - builder.length;
          if (room > 0) {
            builder.add(room >= chunk.length ? chunk : chunk.sublist(0, room));
          }
          controller.add(chunk);
        },
        onError: (Object error, StackTrace stackTrace) {
          onError(error);
          finish();
          controller.addError(error, stackTrace);
        },
        onDone: () {
          finish();
          controller.close();
        },
        cancelOnError: true,
      );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () => subscription?.cancel(),
  );

  return controller.stream;
}

/// Pairs a captured call's id with the stopwatch tracking its duration.
class _RequestCapture {
  const _RequestCapture({required this.id, required this.stopwatch});

  final String id;
  final Stopwatch stopwatch;
}

/// Pairs a captured body with its best-effort original size in bytes.
class _BodyCapture {
  const _BodyCapture(this.body, this.size);

  final CapturedBody body;
  final int? size;
}
