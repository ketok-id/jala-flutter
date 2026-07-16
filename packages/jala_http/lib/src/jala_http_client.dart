import 'dart:async';
import 'dart:convert';
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

  /// Cadence for [NetworkProgressEvent] emission on either side of a call:
  /// every ~64 KB transferred, plus unconditionally on the first and last
  /// chunk — matches the response-side tee's existing granularity (see
  /// [_teeAndCapture]) so upload and download progress read consistently.
  static const int _progressThresholdBytes = 64 * 1024;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final JalaBinding binding = JalaBinding.instance;
    if (!binding.isEnabled) {
      return _inner.send(request);
    }

    String? id;
    Stopwatch? stopwatch;
    _BodyCapture? bodyCapture;
    String? replayOf;
    try {
      final String? replayHeader = request.headers[replayOfHeader];
      if (replayHeader != null) {
        request.headers.remove(replayOfHeader);
        replayOf = replayHeader;
      }
      id = JalaIdGenerator.next();
      stopwatch = Stopwatch()..start();
      bodyCapture = _captureRequestBody(
        request,
        maxBytes: binding.config.maxBodyBytes,
      );
    } catch (_) {
      // A capture bug must never break the app's networking; fall back to
      // an uncaptured passthrough for this call.
    }

    if (id == null || bodyCapture == null || stopwatch == null) {
      return _inner.send(request);
    }
    final String callId = id;
    final Stopwatch sw = stopwatch;

    final JalaMockRule? rule = binding.mockRegistry.match(
      method: request.method.toUpperCase(),
      uri: request.url,
      bodyText: bodyCapture.body.text,
    );

    try {
      final Map<String, String> headers = binding.config.redactor
          .redactHeaders(request.headers);
      binding.bus.emit(
        NetworkRequestEvent(
          callId: callId,
          timestamp: DateTime.now(),
          method: request.method.toUpperCase(),
          uri: request.url,
          headers: headers,
          body: bodyCapture.body,
          size: bodyCapture.size,
          client: 'http',
          replayOf: replayOf,
          mockRuleId: rule?.id,
        ),
      );
    } catch (_) {
      // Continue even if emit fails.
    }

    if (rule != null) {
      final http.StreamedResponse? mocked = await _applyMock(
        rule,
        request,
        callId: callId,
        stopwatch: sw,
        binding: binding,
      );
      if (mocked != null) return mocked;
      // MockDelay falls through to the real network below.
    }

    // Shared between the upload (this method) and download (_captureResponse)
    // sides so every emitted NetworkProgressEvent reports both sides'
    // latest known values together — see B4 in docs/plans/track-b-v0.2.md.
    final _ProgressState progressState = _ProgressState();
    http.BaseRequest outgoing = request;
    try {
      progressState.sentTotal = request.contentLength;
      outgoing = _wrapForUploadProgress(
        request,
        callId: callId,
        binding: binding,
        state: progressState,
      );
    } catch (_) {
      // A bug in the upload-progress wrapper must never break the app's
      // networking; fall back to sending the original, unwrapped request —
      // this just means no upload progress is observed for this call.
      outgoing = request;
    }

    try {
      final http.StreamedResponse response = await _inner.send(outgoing);
      return _captureResponse(
        response,
        callId: callId,
        stopwatch: sw,
        binding: binding,
        progressState: progressState,
      );
    } catch (error) {
      try {
        binding.bus.emit(
          NetworkErrorEvent(
            callId: callId,
            timestamp: DateTime.now(),
            errorMessage: error.toString(),
            duration: sw.elapsed,
          ),
        );
      } catch (_) {
        // A capture bug must never break the app's networking.
      }
      rethrow;
    }
  }

  /// Applies [rule]. Returns a synthetic response for response/failure
  /// actions, or null for [MockDelay] (caller continues to the network).
  Future<http.StreamedResponse?> _applyMock(
    JalaMockRule rule,
    http.BaseRequest request, {
    required String callId,
    required Stopwatch stopwatch,
    required JalaBinding binding,
  }) async {
    try {
      final Duration? delay = rule.action.delay;
      if (delay != null && delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      switch (rule.action) {
        case final MockDelay _:
          return null;
        case final MockResponse action:
          final List<int> bytes = utf8.encode(action.body);
          final CapturedBody body = CapturedBody.capture(
            action.body,
            contentType: action.headers.entries
                .where(
                  (MapEntry<String, String> e) =>
                      e.key.toLowerCase() == 'content-type',
                )
                .map((MapEntry<String, String> e) => e.value)
                .firstOrNull,
            maxBytes: binding.config.maxBodyBytes,
          );
          binding.bus.emit(
            NetworkResponseEvent(
              callId: callId,
              timestamp: DateTime.now(),
              statusCode: action.statusCode,
              headers: binding.config.redactor.redactHeaders(action.headers),
              body: body,
              size: bytes.length,
              duration: stopwatch.elapsed,
            ),
          );
          return http.StreamedResponse(
            Stream<List<int>>.value(bytes),
            action.statusCode,
            contentLength: bytes.length,
            request: request,
            headers: action.headers,
          );
        case final MockFailure action:
          final String message = action.kind == MockFailureKind.timeout
              ? 'Jala mock timeout'
              : 'Jala mock connection error';
          binding.bus.emit(
            NetworkErrorEvent(
              callId: callId,
              timestamp: DateTime.now(),
              errorMessage: message,
              duration: stopwatch.elapsed,
            ),
          );
          if (action.kind == MockFailureKind.timeout) {
            throw TimeoutException(message);
          }
          throw http.ClientException(message, request.url);
      }
    } on TimeoutException {
      rethrow;
    } on http.ClientException {
      rethrow;
    } catch (_) {
      // Mock application bug: fall through to real network.
      return null;
    }
  }

  @override
  void close() {
    _inner.close();
  }

  _BodyCapture _captureRequestBody(
    http.BaseRequest request, {
    required int maxBytes,
  }) {
    if (request is http.MultipartRequest) {
      final List<JalaMultipartPart> parts = <JalaMultipartPart>[
        for (final MapEntry<String, String> entry in request.fields.entries)
          JalaMultipartPart(
            name: entry.key,
            size: utf8.encode(entry.value).length,
          ),
        for (final http.MultipartFile file in request.files)
          JalaMultipartPart(
            name: file.field,
            filename: file.filename,
            contentType: file.contentType.mimeType,
            size: file.length,
          ),
      ];
      final CapturedBody body = CapturedBodyMultipart.capture(
        parts,
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
    required _ProgressState progressState,
  }) {
    final int maxBytes = binding.config.maxBodyBytes;
    final String? contentType = _headerValue(response.headers, 'content-type');
    progressState.receivedTotal = response.contentLength;
    int lastEmittedAt = 0;

    final Stream<List<int>> teed = _teeAndCapture(
      response.stream,
      maxBytes: maxBytes,
      onChunk: (int totalSoFar) {
        progressState.receivedBytes = totalSoFar;
        if (lastEmittedAt == 0 ||
            totalSoFar - lastEmittedAt >= _progressThresholdBytes) {
          lastEmittedAt = totalSoFar;
          _emitProgress(binding, callId, progressState);
        }
      },
      onDone: (List<int> buffered, int totalLength, bool truncated) {
        try {
          progressState.receivedBytes = totalLength;
          _emitProgress(binding, callId, progressState);
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

  /// Wraps [request]'s finalized body stream so upload progress can be
  /// observed, re-hosting it on a fresh [http.BaseRequest] proxy
  /// ([_ProgressUploadRequest]) that carries the same method/url/headers/
  /// contentLength/redirect settings as [request].
  ///
  /// This is transparent to [_inner]: every [http.Client] implementation
  /// only ever reads a [http.BaseRequest]'s generic properties plus
  /// [http.BaseRequest.finalize] (see e.g. `IOClient.send`), never its
  /// concrete runtime type. [request] is finalized here — exactly once, as
  /// it would be by [_inner] regardless — and request-side capture in
  /// [_captureRequest] always runs first and never touches [request]'s
  /// body stream, so finalizing it here is safe.
  http.BaseRequest _wrapForUploadProgress(
    http.BaseRequest request, {
    required String callId,
    required JalaBinding binding,
    required _ProgressState state,
  }) {
    final Stream<List<int>> original = request.finalize();
    int sent = 0;
    int lastEmittedAt = 0;
    final Stream<List<int>> teed = original.transform(
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
    return _ProgressUploadRequest(request, teed);
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
}

/// Tees [source] into a new stream that forwards every chunk to the
/// caller unmodified, while separately buffering at most [maxBytes] of it
/// for capture and counting the true total length.
///
/// [source] is only subscribed to once the returned stream is listened to,
/// mirroring normal `Stream` semantics. [onDone] fires exactly once — on
/// normal completion, on error, or if the caller cancels its subscription
/// mid-read — with the buffered prefix (never larger than [maxBytes]), the
/// true total byte count, and whether the stream exceeded [maxBytes] (and
/// was therefore only partially buffered). [onError] fires (in addition to
/// the error being forwarded to the caller) if [source] errors before
/// completing. [onChunk], if given, fires after every chunk with the
/// running total byte count — used to drive download-progress events
/// without needing a second subscription to [source].
Stream<List<int>> _teeAndCapture(
  Stream<List<int>> source, {
  required int maxBytes,
  required void Function(List<int> buffered, int totalLength, bool truncated)
  onDone,
  required void Function(Object error) onError,
  void Function(int totalSoFar)? onChunk,
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
          onChunk?.call(total);
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
    onCancel: () {
      // If the caller cancels its subscription to the teed stream mid-read
      // (before the source completes on its own), `onDone` above never
      // fires — without this, `finish()` (and therefore the capture
      // callback that completes the store entry) would never run, leaving
      // the entry pending forever. Finish with whatever was buffered so
      // far; `finished` guards against also running when this fires after
      // a normal completion.
      final Future<void>? result = subscription?.cancel();
      finish();
      return result;
    },
  );

  return controller.stream;
}

/// Pairs a captured body with its best-effort original size in bytes.
class _BodyCapture {
  const _BodyCapture(this.body, this.size);

  final CapturedBody body;
  final int? size;
}

/// Mutable, per-call running totals shared between the upload wrapper
/// ([JalaHttpClient._wrapForUploadProgress]) and the response tee
/// ([JalaHttpClient._captureResponse]), so every emitted
/// [NetworkProgressEvent] reports both sides' latest known values together
/// rather than one side clobbering the other's last-known figure.
class _ProgressState {
  int sentBytes = 0;
  int? sentTotal;
  int receivedBytes = 0;
  int? receivedTotal;
}

/// A [http.BaseRequest] that copies its originating request's method/url/
/// headers/contentLength/redirect settings but serves [_body] as its
/// finalized byte stream.
///
/// Used only to re-host an already-finalized request body stream (see
/// [JalaHttpClient._wrapForUploadProgress]) — the original request must
/// have already been finalized by the time this is constructed.
///
/// SPEC-NOTE: this does not forward `http.Abortable.abortTrigger` — a
/// newer, opt-in `package:http` mixin some apps use for request
/// cancellation. That's an accepted, narrow limitation: an abortable
/// request loses upload-progress tracking rather than the other way
/// around, since preserving cancellation matters more.
class _ProgressUploadRequest extends http.BaseRequest {
  _ProgressUploadRequest(http.BaseRequest original, this._body)
    : super(original.method, original.url) {
    headers.addAll(original.headers);
    followRedirects = original.followRedirects;
    maxRedirects = original.maxRedirects;
    persistentConnection = original.persistentConnection;
    final int? length = original.contentLength;
    if (length != null) contentLength = length;
  }

  final Stream<List<int>> _body;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body);
  }
}
