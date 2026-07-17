import 'dart:convert';

import 'package:gql/ast.dart';
import 'package:gql/language.dart' show printNode;
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:jala_core/jala_core.dart';

/// A `gql_link` [Link] that captures every GraphQL operation flowing
/// through it into `JalaBinding.instance`'s store.
///
/// Insert it **before** the terminating link (the one that actually talks
/// to the network, e.g. `HttpLink`) so it observes the outgoing
/// [Request]/incoming [Response] for every operation:
///
/// ```dart
/// final link = Link.from([
///   JalaGraphQLLink(endpoint: uri),
///   HttpLink(uri.toString()),
/// ]);
/// ```
///
/// This works for both `graphql_flutter` and `ferry`, since both are built
/// on top of `gql_link`.
///
/// ### Endpoint URL
///
/// `gql_link` links never see the URL a downstream `HttpLink` is configured
/// with — that's private to the terminating link. Pass [endpoint] so
/// captured entries show the real GraphQL endpoint; when omitted, entries
/// fall back to [placeholderEndpoint] (`graphql://unknown-endpoint`), which
/// is clearly not a real, dereferenceable URL but keeps
/// `NetworkRequestEvent.uri`/`NetworkCallEntry.uri` non-null (both are
/// required fields).
///
/// ### Double-capture
///
/// If the app *also* wraps its HTTP transport with `jala_dio`/`jala_http`
/// (e.g. the same `Dio`/`http.Client` instance `HttpLink` uses internally),
/// the same GraphQL operation is captured twice: once here as a GraphQL
/// entry (`operationName`/`operationType` set, `client: 'graphql'`), and
/// once as a raw POST by the HTTP adapter. Recommendation: either don't
/// wrap the transport used by GraphQL, or filter the inspector list with
/// `-is:graphql`/`is:graphql` to see one or the other.
///
/// ### Subscriptions
///
/// Every payload delivered on an open subscription is captured as a
/// [NetworkSubscriptionPayloadEvent] (`seq` incrementing from 0), appended
/// to the entry's `payloads` ring buffer (see docs/plans/track-e-v0.5.md
/// E1/E2) — superseding the v0.4 `{"@subscription": {"payloads": N}}` body
/// convention. The entry's request event still fires immediately
/// (`operationType: 'subscription'`, status pending); when the underlying
/// stream closes, a single completion response event is still emitted
/// using the **first** payload's `data`/`errors` as the response body, with
/// `statusMessage: 'subscription completed'`.
///
/// ### Production safety
///
/// Mirrors `JalaDioInterceptor`'s conventions: [request] checks
/// `JalaBinding.instance.isEnabled` first and is a true zero-cost
/// passthrough when disabled, and every piece of capture work is wrapped in
/// `try`/`catch` so a bug in Jala's own capture logic can never break the
/// host app's GraphQL flow — the real request is always forwarded exactly
/// once, capture succeeds or not.
class JalaGraphQLLink extends Link {
  /// Creates a link. [endpoint] is used verbatim as the captured entry's
  /// URI; see the "Endpoint URL" section above.
  JalaGraphQLLink({this.endpoint});

  /// The GraphQL endpoint this link's operations are sent to, used only for
  /// display in captured entries (`NetworkRequestEvent.uri`). Not sent
  /// anywhere and not required to be the same value passed to the
  /// terminating link, though it should be for the captured entry to make
  /// sense.
  final Uri? endpoint;

  /// Placeholder URI used for captured entries when [endpoint] is omitted.
  ///
  /// Not a real, resolvable URL — `gql_link` links have no way to observe
  /// the endpoint a downstream terminating link (e.g. `HttpLink`) is
  /// configured with, so this documents "endpoint unknown" without making
  /// `NetworkRequestEvent.uri` nullable.
  static final Uri placeholderEndpoint = Uri.parse(
    'graphql://unknown-endpoint',
  );

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    if (forward == null) {
      // `JalaGraphQLLink` is meant to sit in front of a terminating link
      // (see class docs) and is never itself terminating, so `forward` is
      // always supplied by `Link.from`/`Link.concat` in correct usage. This
      // is a configuration error, not a capture bug — surface it plainly
      // rather than silently swallowing the call.
      return Stream<Response>.error(
        StateError(
          'JalaGraphQLLink must not be the last link in the chain — insert '
          'it before a terminating link, e.g. '
          'Link.from([JalaGraphQLLink(), HttpLink(...)]).',
        ),
      );
    }

    if (!JalaBinding.instance.isEnabled) {
      return forward(request);
    }

    return _instrument(request, forward);
  }

  Stream<Response> _instrument(Request request, NextLink forward) {
    final JalaBinding binding = JalaBinding.instance;
    final String callId = JalaIdGenerator.next();
    final Stopwatch stopwatch = Stopwatch()..start();

    _OperationInfo info;
    try {
      info = _describeOperation(request);
      _emitRequest(binding, callId, request, info);
    } catch (_) {
      // A capture bug must never break the app's GraphQL flow — fall
      // through with no capture at all for this call; the call itself
      // still executes normally.
      return forward(request);
    }

    final Stream<Response> upstream;
    try {
      upstream = forward(request);
    } catch (error) {
      try {
        _emitError(binding, callId, stopwatch, error);
      } catch (_) {
        // Ignore secondary capture failures.
      }
      rethrow;
    }

    return info.type == 'subscription'
        ? _tapSubscription(binding, callId, stopwatch, upstream)
        : _tapSingle(binding, callId, stopwatch, upstream);
  }

  /// Taps a query/mutation stream: captures only the *first* [Response]
  /// (the normal case — queries/mutations resolve exactly once) and
  /// forwards every event untouched, so this link stays fully transparent
  /// to whatever's downstream.
  Stream<Response> _tapSingle(
    JalaBinding binding,
    String callId,
    Stopwatch stopwatch,
    Stream<Response> upstream,
  ) async* {
    bool captured = false;
    try {
      await for (final Response response in upstream) {
        if (!captured) {
          captured = true;
          try {
            _emitResponse(binding, callId, stopwatch, response);
          } catch (_) {
            // Ignore capture failures.
          }
        }
        yield response;
      }
    } catch (error) {
      try {
        _emitError(binding, callId, stopwatch, error);
      } catch (_) {
        // Ignore secondary capture failures.
      }
      rethrow;
    }
  }

  /// Taps a subscription stream: forwards every payload untouched, emits a
  /// [NetworkSubscriptionPayloadEvent] per payload (`seq` incrementing from
  /// 0), and emits a single completion [NetworkResponseEvent] once the
  /// stream closes — see the "Subscriptions" section in the class docs.
  Stream<Response> _tapSubscription(
    JalaBinding binding,
    String callId,
    Stopwatch stopwatch,
    Stream<Response> upstream,
  ) async* {
    Response? firstPayload;
    int payloadCount = 0;
    try {
      await for (final Response response in upstream) {
        final int seq = payloadCount;
        payloadCount++;
        firstPayload ??= response;
        try {
          _emitSubscriptionPayload(binding, callId, seq, response);
        } catch (_) {
          // Ignore capture failures.
        }
        yield response;
      }
      try {
        _emitSubscriptionCompletion(binding, callId, stopwatch, firstPayload);
      } catch (_) {
        // Ignore capture failures.
      }
    } catch (error) {
      try {
        _emitError(binding, callId, stopwatch, error);
      } catch (_) {
        // Ignore secondary capture failures.
      }
      rethrow;
    }
  }

  void _emitRequest(
    JalaBinding binding,
    String callId,
    Request request,
    _OperationInfo info,
  ) {
    // The captured body mirrors the standard GraphQL-over-HTTP request
    // shape (`{operationName, query, variables}`) so the inspector's
    // GraphQL detail view (and any future cURL/HAR export) can read
    // `query`/`variables` straight out of `requestBody.text` the same way
    // it already reads plain JSON bodies for HTTP calls.
    final Map<String, dynamic> payload = <String, dynamic>{
      'operationName': request.operation.operationName,
      'query': info.queryText,
      'variables': request.variables,
    };
    final String rawJson = jsonEncode(payload);
    // SPEC-NOTE: mirrors `JalaDioInterceptor`'s `_redactedCapture` — body
    // patterns are applied to the full body text (here: the whole
    // `{operationName, query, variables}` JSON), which in practice redacts
    // whatever falls inside `variables` without needing to reconstruct the
    // JSON after redacting only a substring.
    final String redactedJson = binding.config.redactor.redactBody(rawJson);
    final CapturedBody body = CapturedBody.capture(
      redactedJson,
      contentType: 'application/json',
      maxBytes: binding.config.maxBodyBytes,
    );

    binding.bus.emit(
      NetworkRequestEvent(
        callId: callId,
        timestamp: DateTime.now(),
        method: 'POST',
        uri: endpoint ?? placeholderEndpoint,
        headers: const <String, String>{},
        body: body,
        client: 'graphql',
        operationName: info.name,
        operationType: info.type,
      ),
    );
  }

  void _emitResponse(
    JalaBinding binding,
    String callId,
    Stopwatch stopwatch,
    Response response,
  ) {
    final bool hasErrors =
        response.errors != null && response.errors!.isNotEmpty;
    final CapturedBody body = _capturePayload(binding, response);

    binding.bus.emit(
      NetworkResponseEvent(
        callId: callId,
        timestamp: DateTime.now(),
        // 200 is a convention for a transport-successful GraphQL call:
        // GraphQL reports application-level failures via `errors` in a
        // 200 response body, not via HTTP status codes.
        statusCode: 200,
        statusMessage: hasErrors ? 'GraphQL errors' : null,
        headers: const <String, String>{},
        body: body,
        duration: stopwatch.elapsed,
      ),
    );
  }

  /// Emits one [NetworkSubscriptionPayloadEvent] for [response], the
  /// [seq]-th payload delivered on this subscription (see
  /// docs/plans/track-e-v0.5.md E1/E2 — supersedes the v0.4
  /// `{"@subscription": {"payloads": N}}` body convention).
  void _emitSubscriptionPayload(
    JalaBinding binding,
    String callId,
    int seq,
    Response response,
  ) {
    binding.bus.emit(
      NetworkSubscriptionPayloadEvent(
        callId: callId,
        timestamp: DateTime.now(),
        seq: seq,
        body: _capturePayload(binding, response),
      ),
    );
  }

  void _emitSubscriptionCompletion(
    JalaBinding binding,
    String callId,
    Stopwatch stopwatch,
    Response? firstPayload,
  ) {
    final CapturedBody body = firstPayload == null
        ? CapturedBody.capture(
            const <String, dynamic>{},
            contentType: 'application/json',
            maxBytes: binding.config.maxBodyBytes,
          )
        : _capturePayload(binding, firstPayload);

    binding.bus.emit(
      NetworkResponseEvent(
        callId: callId,
        timestamp: DateTime.now(),
        statusCode: 200,
        statusMessage: 'subscription completed',
        headers: const <String, String>{},
        body: body,
        // Total time the subscription was open, from the moment the
        // request was issued to the moment its stream closed.
        duration: stopwatch.elapsed,
      ),
    );
  }

  /// Captures a GraphQL response's `data`/`errors` as the standard
  /// `{"data": ..., "errors": [...]}` shape shared by [_emitResponse],
  /// [_emitSubscriptionPayload], and [_emitSubscriptionCompletion].
  ///
  /// SPEC-NOTE: `response.data` is already a decoded `Map`/`null`, not a
  /// `String` — like `JalaDioInterceptor`'s response capture, only
  /// `String` bodies go through `JalaRedactor.redactBody` (pattern-based
  /// redaction needs text to match against); a `Map` here is captured
  /// as-is, same as the non-string branch of `_redactedCapture`.
  CapturedBody _capturePayload(JalaBinding binding, Response response) {
    final bool hasErrors =
        response.errors != null && response.errors!.isNotEmpty;
    final Map<String, dynamic> payload = <String, dynamic>{
      'data': response.data,
      if (hasErrors)
        'errors': <Map<String, dynamic>>[
          for (final GraphQLError error in response.errors!)
            _errorToJson(error),
        ],
    };
    return CapturedBody.capture(
      payload,
      contentType: 'application/json',
      maxBytes: binding.config.maxBodyBytes,
    );
  }

  void _emitError(
    JalaBinding binding,
    String callId,
    Stopwatch stopwatch,
    Object error,
  ) {
    binding.bus.emit(
      NetworkErrorEvent(
        callId: callId,
        timestamp: DateTime.now(),
        errorMessage: error.toString(),
        duration: stopwatch.elapsed,
      ),
    );
  }

  Map<String, dynamic> _errorToJson(GraphQLError error) {
    return <String, dynamic>{
      'message': error.message,
      if (error.locations != null)
        'locations': <Map<String, dynamic>>[
          for (final ErrorLocation location in error.locations!)
            <String, dynamic>{'line': location.line, 'column': location.column},
        ],
      if (error.path != null) 'path': error.path,
      if (error.extensions != null) 'extensions': error.extensions,
    };
  }

  _OperationInfo _describeOperation(Request request) {
    final String queryText = printNode(request.operation.document);
    final OperationDefinitionNode? selected = _selectOperationDefinition(
      request,
    );
    final String? explicitName = request.operation.operationName;
    final String name = (explicitName != null && explicitName.isNotEmpty)
        ? explicitName
        : (selected?.name?.value ?? 'anonymous');
    final String type = (selected?.type ?? OperationType.query).name;
    return _OperationInfo(name: name, type: type, queryText: queryText);
  }

  /// Picks the [OperationDefinitionNode] this request actually executes:
  /// the one named `request.operation.operationName` when the document has
  /// multiple operation definitions and a name is given, otherwise the
  /// first operation definition found in document order.
  ///
  /// Never throws — a document with no operation definitions at all (not
  /// valid GraphQL, but Jala must never crash on malformed input) yields
  /// `null`, handled by defensive fallbacks in [_describeOperation].
  OperationDefinitionNode? _selectOperationDefinition(Request request) {
    final String? explicitName = request.operation.operationName;
    OperationDefinitionNode? first;
    for (final DefinitionNode definition
        in request.operation.document.definitions) {
      if (definition is! OperationDefinitionNode) continue;
      first ??= definition;
      if (explicitName != null && definition.name?.value == explicitName) {
        return definition;
      }
    }
    return first;
  }
}

/// Resolved operation metadata for one [Request], computed once per call.
class _OperationInfo {
  const _OperationInfo({
    required this.name,
    required this.type,
    required this.queryText,
  });

  /// Never null/empty — falls back to `'anonymous'`.
  final String name;

  /// `'query'`, `'mutation'`, or `'subscription'`.
  final String type;

  /// Pretty-printed GraphQL source for the whole document (all operation
  /// and fragment definitions), via `package:gql`'s `printNode`.
  final String queryText;
}
