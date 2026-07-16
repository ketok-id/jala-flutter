import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jala_core/jala_core.dart';

import 'jala_http_client.dart';

/// Re-issues a previously captured network call through a `http.Client`
/// (normally the [JalaHttpClient] returned by `JalaHttp.wrap`).
///
/// Rebuilds a [http.Request] from a [NetworkCallEntry]: headers whose
/// value was masked by redaction (`JalaRedactor.mask`) are dropped rather
/// than resent (Jala never retained the real secret to resend), and the
/// body is re-encoded from the entry's captured text where possible. The
/// rebuilt request is tagged with the [JalaHttpClient.replayOfHeader]
/// header, so [JalaHttpClient.send] captures the replay as a fresh entry
/// with `replayOf` set to the original call's id.
class JalaHttpReplayer implements JalaReplayer {
  /// Creates a replayer that issues replayed calls through [client].
  ///
  /// Prefer `JalaHttp.wrap`, which constructs and registers this for you.
  JalaHttpReplayer(this._client);

  final http.Client _client;

  @override
  Future<void> replay(NetworkCallEntry entry) async {
    await _send(_buildRequest(entry));
  }

  @override
  Future<void> replayModified(
    NetworkCallEntry entry, {
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    String? body,
  }) async {
    await _send(
      _buildRequest(
        entry,
        method: method,
        uri: uri,
        headers: headers,
        bodyOverride: body,
      ),
    );
  }

  http.Request _buildRequest(
    NetworkCallEntry entry, {
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    String? bodyOverride,
  }) {
    final Map<String, String> sourceHeaders =
        headers ?? entry.requestHeaders;
    final http.Request request = http.Request(
      method ?? entry.method,
      uri ?? entry.uri,
    )
      ..headers.addAll(<String, String>{
        for (final MapEntry<String, String> header in sourceHeaders.entries)
          if (header.value != JalaRedactor.mask) header.key: header.value,
      })
      ..headers[JalaHttpClient.replayOfHeader] = entry.id;

    if (bodyOverride != null) {
      request.body = bodyOverride;
    } else {
      final List<int>? bytes = _rebuildBodyBytes(entry.requestBody);
      if (bytes != null) {
        request.bodyBytes = bytes;
      }
    }
    return request;
  }

  Future<void> _send(http.Request request) async {
    try {
      final http.StreamedResponse response = await _client.send(request);
      // [JalaHttpClient.send] only captures the response once its stream
      // is drained (see the tee in `jala_http_client.dart`) — the caller
      // here doesn't care about the replayed body, but must still drain
      // it so the replay is recorded as a completed entry rather than
      // staying pending forever.
      await response.stream.drain<void>();
    } on Object {
      // The client already records the replayed call's failure as a
      // fresh entry (with `replayOf` set); the caller doesn't need the
      // exception rethrown here.
    }
  }

  List<int>? _rebuildBodyBytes(CapturedBody body) {
    switch (body.kind) {
      case BodyKind.json:
      case BodyKind.text:
      case BodyKind.truncated:
        final String? text = body.text;
        return text == null ? null : utf8.encode(text);
      case BodyKind.bytes:
      case BodyKind.stream:
      case BodyKind.image:
      case BodyKind.none:
        return null;
    }
  }
}
