import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A minimal fake `http.Client` that resolves every request through a
/// caller-supplied [handler], so tests never touch real network I/O.
///
/// Every [http.BaseRequest] passed to [handler] is also appended to
/// [requests], so tests can assert on exactly what was sent over the wire
/// (e.g. that a redacted header was never resent on replay).
class FakeHttpClient extends http.BaseClient {
  FakeHttpClient(this.handler);

  /// Produces the [http.StreamedResponse] for a given request, or throws
  /// to simulate a transport-level failure.
  final FutureOr<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  /// Every [http.BaseRequest] this client has been asked to send, in
  /// order.
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  /// The finalized request body bytes actually read for each entry in
  /// [requests], in order — since a request can only be finalized once,
  /// this is how tests inspect what was sent instead of calling
  /// `request.finalize()` themselves (which would throw the second time).
  final List<List<int>> requestBodies = <List<int>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    // A real client always reads the finalized body stream (to write it to
    // the socket); do the same here so tests can exercise upload-progress
    // wrapping (see JalaHttpClient._wrapForUploadProgress) without a real
    // transport, and inspect what was actually sent via [requestBodies].
    final List<int> bytes = await request
        .finalize()
        .expand((chunk) => chunk)
        .toList();
    requestBodies.add(bytes);
    return handler(request);
  }

  @override
  void close() {}
}

/// Builds a [http.StreamedResponse] whose body streams [chunks] one chunk
/// at a time, optionally with a delay between chunks — used to exercise
/// the response stream tee with a slow/chunked source.
http.StreamedResponse chunkedStreamedResponse(
  List<List<int>> chunks, {
  int statusCode = 200,
  String? reasonPhrase,
  Map<String, String>? headers,
  Duration? delayBetweenChunks,
  http.BaseRequest? request,
  int? contentLength,
}) {
  Stream<List<int>> bodyStream() async* {
    for (final List<int> chunk in chunks) {
      if (delayBetweenChunks != null) {
        await Future<void>.delayed(delayBetweenChunks);
      }
      yield chunk;
    }
  }

  return http.StreamedResponse(
    bodyStream(),
    statusCode,
    reasonPhrase: reasonPhrase,
    headers: headers ?? const <String, String>{},
    request: request,
    contentLength: contentLength,
  );
}

/// Builds a JSON-encoded [http.StreamedResponse] for [data].
http.StreamedResponse jsonStreamedResponse(
  Object? data, {
  int statusCode = 200,
  String? reasonPhrase,
  Map<String, String>? headers,
  http.BaseRequest? request,
}) {
  final List<int> bytes = utf8.encode(jsonEncode(data));
  return chunkedStreamedResponse(
    <List<int>>[bytes],
    statusCode: statusCode,
    reasonPhrase: reasonPhrase,
    headers: <String, String>{'content-type': 'application/json', ...?headers},
    request: request,
  );
}
