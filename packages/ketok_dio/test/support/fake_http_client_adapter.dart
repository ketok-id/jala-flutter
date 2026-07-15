import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A minimal fake [HttpClientAdapter] that resolves every request through a
/// caller-supplied [handler], so tests never touch real network I/O.
///
/// Every [RequestOptions] passed to [handler] is also appended to
/// [requests], so tests can assert on exactly what was sent over the wire
/// (e.g. that a redacted header was never resent on replay).
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this.handler);

  /// Produces the [ResponseBody] for a given request, or throws (e.g. a
  /// [DioException]) to simulate a transport-level failure.
  final FutureOr<ResponseBody> Function(RequestOptions options) handler;

  /// Every [RequestOptions] this adapter has been asked to fetch, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Builds a JSON-encoded [ResponseBody] for [data].
ResponseBody jsonResponseBody(
  Object? data, {
  int statusCode = 200,
  String? statusMessage,
  Map<String, List<String>>? headers,
}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    statusMessage: statusMessage,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
      ...?headers,
    },
  );
}
