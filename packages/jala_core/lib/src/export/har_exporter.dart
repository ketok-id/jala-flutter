import 'dart:convert';

import '../model/captured_body.dart';
import '../model/network_call_entry.dart';

/// Exports [NetworkCallEntry]s as HAR 1.2 JSON
/// (http://www.softwareishard.com/blog/har-12-spec/).
class HarExporter {
  const HarExporter._();

  /// Exports a whole session (multiple calls) as one HAR document.
  static String exportSession(List<NetworkCallEntry> entries) =>
      const JsonEncoder.withIndent('  ').convert(_log(entries));

  /// Exports a single call as a HAR document with one entry.
  static String exportCall(NetworkCallEntry entry) =>
      exportSession(<NetworkCallEntry>[entry]);

  static Map<String, Object?> _log(List<NetworkCallEntry> entries) =>
      <String, Object?>{
        'log': <String, Object?>{
          'version': '1.2',
          'creator': <String, Object?>{'name': 'jala', 'version': '0.1.0'},
          'entries': entries.map(_entry).toList(),
        },
      };

  static Map<String, Object?> _entry(NetworkCallEntry e) {
    final int timeMs = e.duration?.inMilliseconds ?? 0;
    return <String, Object?>{
      'startedDateTime': e.startTime.toUtc().toIso8601String(),
      'time': timeMs,
      'request': _request(e),
      'response': _response(e),
      'cache': <String, Object?>{},
      // Sub-phases Jala does not measure are -1 per the HAR spec; the
      // whole measured duration is attributed to `wait`.
      'timings': <String, Object?>{'send': -1, 'wait': timeMs, 'receive': -1},
    };
  }

  static Map<String, Object?> _request(NetworkCallEntry e) {
    final Map<String, Object?> request = <String, Object?>{
      'method': e.method,
      'url': e.uri.toString(),
      'httpVersion': 'HTTP/1.1',
      'cookies': <Object?>[],
      'headers': _headers(e.requestHeaders),
      'queryString': [
        for (final MapEntry<String, String> param
            in e.uri.queryParameters.entries)
          <String, Object?>{'name': param.key, 'value': param.value},
      ],
      'headersSize': -1,
      'bodySize': e.requestSize ?? e.requestBody.originalSize ?? -1,
    };
    final String? bodyText = _bodyText(e.requestBody);
    if (bodyText != null) {
      request['postData'] = <String, Object?>{
        'mimeType': e.requestBody.contentType ?? 'application/octet-stream',
        'text': bodyText,
      };
    }
    return request;
  }

  static Map<String, Object?> _response(NetworkCallEntry e) {
    final CapturedBody body = e.responseBody;
    final Map<String, Object?> content = <String, Object?>{
      'size': e.responseSize ?? body.originalSize ?? -1,
      'mimeType': body.contentType ?? _headerValue(e, 'content-type') ?? '',
    };
    final String? bodyText = _bodyText(body);
    if (bodyText != null) {
      content['text'] = bodyText;
    }
    return <String, Object?>{
      'status': e.statusCode ?? 0,
      'statusText': e.statusMessage ?? '',
      'httpVersion': 'HTTP/1.1',
      'cookies': <Object?>[],
      'headers': _headers(e.responseHeaders),
      'content': content,
      'redirectURL': _headerValue(e, 'location') ?? '',
      'headersSize': -1,
      'bodySize': e.responseSize ?? body.originalSize ?? -1,
    };
  }

  // SPEC-NOTE: image bodies never surface as base64 in HAR `text` fields —
  // a size/mime placeholder is emitted instead so the exported document
  // stays small and reviewable.
  static String? _bodyText(CapturedBody body) {
    if (body.kind == BodyKind.image) {
      return '[${body.contentType ?? 'image'}, ${body.originalSize ?? '?'} '
          'bytes — binary content not exported]';
    }
    return body.text;
  }

  static List<Map<String, Object?>> _headers(Map<String, String> headers) => [
    for (final MapEntry<String, String> header in headers.entries)
      <String, Object?>{'name': header.key, 'value': header.value},
  ];

  static String? _headerValue(NetworkCallEntry e, String name) {
    for (final MapEntry<String, String> header in e.responseHeaders.entries) {
      if (header.key.toLowerCase() == name) return header.value;
    }
    return null;
  }
}
