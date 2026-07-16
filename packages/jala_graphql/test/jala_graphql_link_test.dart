import 'dart:convert';

import 'package:gql/language.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_graphql/jala_graphql.dart';
import 'package:test/test.dart';

import 'support/fake_terminating_link.dart';

/// Builds a `gql_exec` [Request] by parsing [source] as GraphQL.
Request buildRequest(
  String source, {
  String? operationName,
  Map<String, dynamic> variables = const <String, dynamic>{},
}) {
  return Request(
    operation: Operation(
      document: parseString(source),
      operationName: operationName,
    ),
    variables: variables,
  );
}

/// Builds a terminating-link-style [Response].
Response gqlResponse(
  Map<String, dynamic>? data, {
  List<GraphQLError>? errors,
}) {
  return Response(
    data: data,
    errors: errors,
    response: const <String, dynamic>{},
  );
}

Map<String, dynamic> decodeBody(CapturedBody body) =>
    jsonDecode(body.text!) as Map<String, dynamic>;

/// Flushes pending microtasks so async event-bus deliveries settle — the
/// store's subscription to `JalaEventBus.events` (a broadcast stream)
/// receives each emitted event on its own microtask turn, so a capture
/// event emitted synchronously inside `JalaGraphQLLink` is not necessarily
/// visible in `JalaBinding.instance.store.entries` until a tick later. Same
/// convention as `jala_dio`'s tests.
Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  tearDown(JalaBinding.resetForTesting);

  group('JalaGraphQLLink queries/mutations', () {
    test('captures a named query: name, type, query text, variables', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeTerminatingLink terminating = FakeTerminatingLink()
        ..respondWith(<Response>[
          gqlResponse(<String, dynamic>{
            'user': <String, dynamic>{'id': '1', 'name': 'Ada'},
          }),
        ]);
      final Uri endpoint = Uri.parse('https://api.example.com/graphql');
      final JalaGraphQLLink link = JalaGraphQLLink(endpoint: endpoint);

      final Request request = buildRequest(
        'query GetUser(\$id: ID!) { user(id: \$id) { id name } }',
        operationName: 'GetUser',
        variables: <String, dynamic>{'id': '1'},
      );

      final List<Response> responses = await link
          .request(request, terminating.request)
          .toList();
      expect(responses, hasLength(1));
      expect(responses.single.data, <String, dynamic>{
        'user': <String, dynamic>{'id': '1', 'name': 'Ada'},
      });

      final NetworkCallEntry entry = JalaBinding.instance.store.entries.single;
      expect(entry.client, 'graphql');
      expect(entry.method, 'POST');
      expect(entry.uri, endpoint);
      expect(entry.operationName, 'GetUser');
      expect(entry.operationType, 'query');
      expect(entry.status, JalaCallStatus.success);
      expect(entry.statusCode, 200);
      expect(entry.statusMessage, isNull);
      expect(entry.duration, isNotNull);

      final Map<String, dynamic> requestJson = decodeBody(entry.requestBody);
      expect(requestJson['operationName'], 'GetUser');
      expect(requestJson['query'], contains('GetUser'));
      expect(requestJson['variables'], <String, dynamic>{'id': '1'});

      final Map<String, dynamic> responseJson = decodeBody(
        entry.responseBody,
      );
      expect(responseJson['data'], <String, dynamic>{
        'user': <String, dynamic>{'id': '1', 'name': 'Ada'},
      });
      expect(responseJson.containsKey('errors'), isFalse);
    });

    test('falls back to \'anonymous\' for an unnamed operation', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeTerminatingLink terminating = FakeTerminatingLink()
        ..respondWith(<Response>[
          gqlResponse(<String, dynamic>{
            'hero': <String, dynamic>{'name': 'Luke'},
          }),
        ]);
      final JalaGraphQLLink link = JalaGraphQLLink();

      final Request request = buildRequest('{ hero { name } }');
      await link.request(request, terminating.request).toList();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries.single;
      expect(entry.operationName, 'anonymous');
      expect(entry.operationType, 'query');
      // No `endpoint` supplied -> placeholder URL is used.
      expect(entry.uri, JalaGraphQLLink.placeholderEndpoint);
    });

    test('captures a mutation with its operationType', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeTerminatingLink terminating = FakeTerminatingLink()
        ..respondWith(<Response>[
          gqlResponse(<String, dynamic>{
            'createUser': <String, dynamic>{'id': '42'},
          }),
        ]);
      final JalaGraphQLLink link = JalaGraphQLLink();

      final Request request = buildRequest(
        'mutation CreateUser(\$name: String!) { createUser(name: \$name) { id } }',
        operationName: 'CreateUser',
        variables: <String, dynamic>{'name': 'Grace'},
      );
      await link.request(request, terminating.request).toList();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries.single;
      expect(entry.operationName, 'CreateUser');
      expect(entry.operationType, 'mutation');
    });

    test('redacts variables via the configured body pattern', () async {
      JalaBinding.instance.initialize(
        config: JalaConfig(
          enabled: true,
          redactor: JalaRedactor(
            redactedBodyPatterns: <Pattern>[RegExp('super-secret')],
          ),
        ),
      );
      final FakeTerminatingLink terminating = FakeTerminatingLink()
        ..respondWith(<Response>[gqlResponse(<String, dynamic>{'ok': true})]);
      final JalaGraphQLLink link = JalaGraphQLLink();

      final Request request = buildRequest(
        'mutation Login(\$password: String!) { login(password: \$password) }',
        operationName: 'Login',
        variables: <String, dynamic>{'password': 'super-secret'},
      );
      await link.request(request, terminating.request).toList();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries.single;
      expect(entry.requestBody.text, isNot(contains('super-secret')));
      expect(entry.requestBody.text, contains(JalaRedactor.mask));
      final Map<String, dynamic> requestJson = decodeBody(entry.requestBody);
      expect(
        (requestJson['variables'] as Map<String, dynamic>)['password'],
        JalaRedactor.mask,
      );
    });

    test('captures GraphQL errors in the response body', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeTerminatingLink terminating = FakeTerminatingLink()
        ..respondWith(<Response>[
          gqlResponse(
            null,
            errors: <GraphQLError>[
              const GraphQLError(message: 'Not authorized'),
            ],
          ),
        ]);
      final JalaGraphQLLink link = JalaGraphQLLink();

      final Request request = buildRequest('query Me { me { id } }');
      await link.request(request, terminating.request).toList();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries.single;
      // GraphQL errors are still a transport-successful 200; the failure
      // is application-level.
      expect(entry.statusCode, 200);
      expect(entry.statusMessage, 'GraphQL errors');
      expect(entry.status, JalaCallStatus.success);

      final Map<String, dynamic> responseJson = decodeBody(
        entry.responseBody,
      );
      final List<dynamic> errors = responseJson['errors'] as List<dynamic>;
      expect(errors, hasLength(1));
      expect(
        (errors.single as Map<String, dynamic>)['message'],
        'Not authorized',
      );
    });

    test('a LinkException from the terminating link -> NetworkErrorEvent', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      const ServerException exception = ServerException(
        originalException: 'connection refused',
      );
      final FakeTerminatingLink terminating = FakeTerminatingLink()
        ..failWith(exception);
      final JalaGraphQLLink link = JalaGraphQLLink();

      final Request request = buildRequest('query Ping { ping }');

      await expectLater(
        link.request(request, terminating.request).toList(),
        throwsA(isA<ServerException>()),
      );
      await pump();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries.single;
      expect(entry.status, JalaCallStatus.error);
      expect(entry.errorMessage, contains('connection refused'));
    });

    test('disabled binding is a pure passthrough — nothing captured', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: false));
      final FakeTerminatingLink terminating = FakeTerminatingLink()
        ..respondWith(<Response>[gqlResponse(<String, dynamic>{'ok': true})]);
      final JalaGraphQLLink link = JalaGraphQLLink();

      final Request request = buildRequest('query Ping { ping }');
      final List<Response> responses = await link
          .request(request, terminating.request)
          .toList();

      expect(responses, hasLength(1));
      expect(identical(terminating.lastRequest, request), isTrue);
      expect(JalaBinding.instance.store.entries, isEmpty);
    });

    test(
      'multiple OperationDefinitions: picks the executed one by operationName',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final FakeTerminatingLink terminating = FakeTerminatingLink()
          ..respondWith(<Response>[
            gqlResponse(<String, dynamic>{
              'second': <String, dynamic>{'ok': true},
            }),
          ]);
        final JalaGraphQLLink link = JalaGraphQLLink();

        final Request request = buildRequest(
          'query First { first } mutation Second { second }',
          operationName: 'Second',
        );
        await link.request(request, terminating.request).toList();

        final NetworkCallEntry entry =
            JalaBinding.instance.store.entries.single;
        expect(entry.operationName, 'Second');
        // The type must come from the *executed* definition (`Second`,
        // a mutation), not simply the first one in document order
        // (`First`, a query).
        expect(entry.operationType, 'mutation');
      },
    );
  });

  group('JalaGraphQLLink subscriptions', () {
    test(
      'emits the request event immediately, then a single completion '
      'response event on close using the first payload',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final FakeTerminatingLink terminating = FakeTerminatingLink()
          ..respondWith(<Response>[
            gqlResponse(<String, dynamic>{
              'messageAdded': <String, dynamic>{'id': '1'},
            }),
            gqlResponse(<String, dynamic>{
              'messageAdded': <String, dynamic>{'id': '2'},
            }),
            gqlResponse(<String, dynamic>{
              'messageAdded': <String, dynamic>{'id': '3'},
            }),
          ]);
        final JalaGraphQLLink link = JalaGraphQLLink();

        final Request request = buildRequest(
          'subscription OnMessage { messageAdded { id } }',
          operationName: 'OnMessage',
        );

        final Stream<Response> stream = link.request(
          request,
          terminating.request,
        );

        // The request event must fire as soon as `request()` is called,
        // before anything has been consumed from the returned stream.
        await pump();
        final NetworkCallEntry pending =
            JalaBinding.instance.store.entries.single;
        expect(pending.operationName, 'OnMessage');
        expect(pending.operationType, 'subscription');
        expect(pending.status, JalaCallStatus.pending);

        final List<Response> payloads = await stream.toList();
        await pump();
        expect(payloads, hasLength(3));

        final NetworkCallEntry entry =
            JalaBinding.instance.store.entries.single;
        expect(entry.status, JalaCallStatus.success);
        expect(entry.statusCode, 200);
        expect(entry.statusMessage, 'subscription completed');
        expect(entry.duration, isNotNull);

        final Map<String, dynamic> responseJson = decodeBody(
          entry.responseBody,
        );
        // Only the *first* payload's data is kept as the response body.
        expect(responseJson['data'], <String, dynamic>{
          'messageAdded': <String, dynamic>{'id': '1'},
        });
        expect(
          responseJson['@subscription'],
          <String, dynamic>{'payloads': 3},
        );
      },
    );

    test('a stream error mid-subscription -> NetworkErrorEvent', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      const ServerException exception = ServerException(
        originalException: 'socket closed',
      );
      final FakeTerminatingLink terminating = FakeTerminatingLink()
        ..respondThenFailWith(<Response>[
          gqlResponse(<String, dynamic>{
            'messageAdded': <String, dynamic>{'id': '1'},
          }),
        ], exception);
      final JalaGraphQLLink link = JalaGraphQLLink();

      final Request request = buildRequest(
        'subscription OnMessage { messageAdded { id } }',
        operationName: 'OnMessage',
      );

      await expectLater(
        link.request(request, terminating.request).toList(),
        throwsA(isA<ServerException>()),
      );
      await pump();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries.single;
      expect(entry.status, JalaCallStatus.error);
      expect(entry.errorMessage, contains('socket closed'));
    });
  });
}
