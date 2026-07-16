import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jala_core/jala_core.dart';

import 'jala_dio_interceptor.dart';

/// Re-issues a previously captured network call through a [Dio] instance.
///
/// Rebuilds [RequestOptions] from a [NetworkCallEntry]: headers whose value
/// was masked by redaction (`JalaRedactor.mask`) are dropped rather than
/// resent (Jala never retained the real secret to resend), and the body is
/// re-encoded from the entry's captured text where possible. The rebuilt
/// request is tagged with `extra[JalaDioInterceptor.replayOfExtraKey]`, so
/// [JalaDioInterceptor] captures the replay as a fresh entry with
/// `replayOf` set to the original call's id.
class JalaDioReplayer implements JalaReplayer {
  /// Creates a replayer that issues replayed calls through [dio].
  ///
  /// Prefer `JalaDio.attach`, which constructs and registers this for you.
  JalaDioReplayer(this._dio);

  final Dio _dio;

  @override
  Future<void> replay(NetworkCallEntry entry) async {
    final RequestOptions options = _rebuildRequestOptions(entry);
    try {
      await _dio.fetch<dynamic>(options);
    } on DioException {
      // The interceptor already records the replayed call's failure as a
      // fresh entry (with `replayOf` set); the caller doesn't need the
      // exception rethrown here.
    }
  }

  RequestOptions _rebuildRequestOptions(NetworkCallEntry entry) {
    final Map<String, dynamic> headers = <String, dynamic>{
      for (final MapEntry<String, String> header
          in entry.requestHeaders.entries)
        if (header.value != JalaRedactor.mask) header.key: header.value,
    };
    return RequestOptions(
      method: entry.method,
      path: entry.uri.toString(),
      headers: headers,
      data: _rebuildData(entry.requestBody),
      extra: <String, dynamic>{JalaDioInterceptor.replayOfExtraKey: entry.id},
    );
  }

  dynamic _rebuildData(CapturedBody body) {
    switch (body.kind) {
      case BodyKind.json:
        final String? text = body.text;
        return text == null ? null : jsonDecode(text);
      case BodyKind.text:
      case BodyKind.truncated:
        return body.text;
      case BodyKind.image:
        // The raw bytes were retained specifically for preview/replay;
        // Dio sends a `Uint8List` body as-is (see `DioMixin._transformData`),
        // so no re-encoding is needed here.
        return body.bytes;
      case BodyKind.bytes:
      case BodyKind.stream:
      case BodyKind.none:
        return null;
    }
  }
}
