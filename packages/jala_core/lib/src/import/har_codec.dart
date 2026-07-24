import 'dart:convert';

import '../model/captured_body.dart';
import '../model/jala_call_status.dart';
import '../model/network_call_entry.dart';
import '../model/ws_connection_entry.dart';
import '../session/jala_session.dart';
import '../session/jala_session_codec.dart';
import '../util/id_generator.dart';

/// Decodes a HAR 1.2 document
/// (http://www.softwareishard.com/blog/har-12-spec/) into a [JalaSession] of
/// imported calls — the inverse of `HarExporter`, and interoperable with HAR
/// files from browser devtools, Charles, Proxyman, etc.
///
/// Every produced [NetworkCallEntry] is flagged `imported: true` (so the UI
/// disables replay, matching session import). Like `JalaSessionCodec.decode`,
/// this only ever throws [JalaSessionFormatException], so the import UI has a
/// single error type to catch.
class JalaHarCodec {
  const JalaHarCodec._();

  /// Parses [harJson] into a session. WebSocket connections are not part of
  /// the HAR spec, so [JalaSession.wsConnections] is always empty.
  static JalaSession decode(String harJson) {
    final Object? root;
    try {
      root = jsonDecode(harJson);
    } on FormatException catch (e) {
      throw JalaSessionFormatException('Malformed HAR JSON: ${e.message}');
    }
    if (root is! Map) {
      throw const JalaSessionFormatException('HAR root is not an object');
    }
    final Object? log = root['log'];
    if (log is! Map) {
      throw const JalaSessionFormatException('HAR is missing a "log" object');
    }
    final Object? entriesRaw = log['entries'];
    if (entriesRaw is! List) {
      throw const JalaSessionFormatException('HAR "log.entries" is not a list');
    }

    try {
      final List<NetworkCallEntry> entries = <NetworkCallEntry>[
        for (final Object? e in entriesRaw)
          if (e is Map) _entry(Map<String, Object?>.from(e)),
      ];
      return JalaSession(
        version: JalaSessionCodec.currentVersion,
        exportedAt: DateTime.now().toUtc(),
        entries: entries,
        wsConnections: const <WsConnectionEntry>[],
      );
    } on JalaSessionFormatException {
      rethrow;
    } on Object catch (e) {
      throw JalaSessionFormatException('Could not parse HAR entry: $e');
    }
  }

  static NetworkCallEntry _entry(Map<String, Object?> e) {
    final Map<String, Object?> request = _obj(e['request'], 'request');
    final Map<String, Object?> response = _obj(e['response'], 'response');

    final String url = request['url'] as String? ?? '';
    if (url.isEmpty) {
      throw const JalaSessionFormatException('HAR entry request has no url');
    }
    final int status = (response['status'] as num?)?.toInt() ?? 0;
    final Map<String, Object?> content = _objOrEmpty(response['content']);
    final Object? postData = request['postData'];

    return NetworkCallEntry(
      id: JalaIdGenerator.next(),
      startTime: _startTime(e['startedDateTime']),
      method: (request['method'] as String? ?? 'GET').toUpperCase(),
      uri: Uri.parse(url),
      requestHeaders: _headerMap(request['headers']),
      requestBody: _body(
        postData is Map ? postData['text'] : null,
        postData is Map ? postData['mimeType'] : null,
      ),
      statusCode: status == 0 ? null : status,
      statusMessage: response['statusText'] as String?,
      responseHeaders: _headerMap(response['headers']),
      responseBody: _body(content['text'], content['mimeType']),
      duration: Duration(milliseconds: ((e['time'] as num?) ?? 0).round()),
      requestSize: _size(request['bodySize']),
      responseSize: _size(content['size']) ?? _size(response['bodySize']),
      status: status > 0 ? JalaCallStatus.success : JalaCallStatus.pending,
      client: 'har',
      imported: true,
    );
  }

  static CapturedBody _body(Object? text, Object? mimeType) {
    if (text is! String || text.isEmpty) return CapturedBody.none;
    return CapturedBody.capture(text, contentType: mimeType as String?);
  }

  static Map<String, String> _headerMap(Object? raw) {
    final Map<String, String> out = <String, String>{};
    if (raw is List) {
      for (final Object? h in raw) {
        if (h is Map && h['name'] is String) {
          out[h['name'] as String] = h['value']?.toString() ?? '';
        }
      }
    }
    return out;
  }

  static DateTime _startTime(Object? raw) {
    if (raw is String) {
      final DateTime? parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now().toUtc();
  }

  static int? _size(Object? raw) {
    if (raw is num) {
      final int v = raw.toInt();
      return v < 0 ? null : v;
    }
    return null;
  }

  static Map<String, Object?> _obj(Object? raw, String what) {
    if (raw is Map) return Map<String, Object?>.from(raw);
    throw JalaSessionFormatException('HAR entry is missing "$what"');
  }

  static Map<String, Object?> _objOrEmpty(Object? raw) =>
      raw is Map ? Map<String, Object?>.from(raw) : <String, Object?>{};
}
