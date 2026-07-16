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
    await _fetch(_rebuildRequestOptions(entry));
  }

  @override
  Future<void> replayModified(
    NetworkCallEntry entry, {
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    String? body,
  }) async {
    await _fetch(
      _rebuildRequestOptions(
        entry,
        method: method,
        uri: uri,
        headers: headers,
        bodyOverride: body,
      ),
    );
  }

  Future<void> _fetch(RequestOptions options) async {
    try {
      await _dio.fetch<dynamic>(options);
    } on DioException {
      // The interceptor already records the replayed call's failure as a
      // fresh entry (with `replayOf` set); the caller doesn't need the
      // exception rethrown here.
    }
  }

  RequestOptions _rebuildRequestOptions(
    NetworkCallEntry entry, {
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    String? bodyOverride,
  }) {
    final Map<String, String> sourceHeaders =
        headers ?? entry.requestHeaders;
    final Map<String, dynamic> rebuiltHeaders = <String, dynamic>{
      for (final MapEntry<String, String> header in sourceHeaders.entries)
        if (header.value != JalaRedactor.mask) header.key: header.value,
    };
    final dynamic data = bodyOverride != null
        ? _dataFromText(bodyOverride)
        : _rebuildData(entry.requestBody);
    return RequestOptions(
      method: method ?? entry.method,
      path: (uri ?? entry.uri).toString(),
      headers: rebuiltHeaders,
      data: data,
      extra: <String, dynamic>{JalaDioInterceptor.replayOfExtraKey: entry.id},
    );
  }

  dynamic _dataFromText(String text) {
    try {
      return jsonDecode(text);
    } on Object {
      return text;
    }
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
