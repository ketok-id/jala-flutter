import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';

/// A terminating [Link] the tests fully control — no real network I/O.
///
/// Records the last [Request] it received (so tests can assert on what
/// [JalaGraphQLLink] forwarded downstream) and replies with whatever
/// [Stream<Response>] the test configures via [respondWith]/[failWith].
class FakeTerminatingLink extends Link {
  Request? lastRequest;
  Stream<Response> Function(Request request)? _handler;

  /// Configures this link to reply with [responses] (a single query/
  /// mutation reply is `[response]`; a subscription is one entry per
  /// payload).
  void respondWith(List<Response> responses) {
    _handler = (request) => Stream<Response>.fromIterable(responses);
  }

  /// Configures this link to reply with a stream that emits [responses]
  /// (if any) and then errors with [error] — simulates a mid-stream
  /// failure (e.g. a dropped subscription).
  void respondThenFailWith(List<Response> responses, Object error) {
    _handler = (request) => Stream<Response>.multi((controller) {
      for (final Response response in responses) {
        controller.add(response);
      }
      controller.addError(error);
      controller.close();
    });
  }

  /// Configures this link to fail immediately with [error] — simulates a
  /// `LinkException` (or any other stream error) from the terminating
  /// link, e.g. a connection failure.
  void failWith(Object error) {
    _handler = (request) => Stream<Response>.error(error);
  }

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    lastRequest = request;
    final Stream<Response> Function(Request request)? handler = _handler;
    if (handler == null) {
      throw StateError(
        'FakeTerminatingLink was not configured — call respondWith/'
        'failWith before using it.',
      );
    }
    return handler(request);
  }
}
