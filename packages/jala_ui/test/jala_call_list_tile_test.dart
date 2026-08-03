import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);
  tearDown(JalaBinding.resetForTesting);

  NetworkCallEntry entry({
    String method = 'GET',
    String url = 'https://api.example.com/users',
    String? operationName,
    String? operationType,
    String client = 'test',
    String? rpcKind,
    int? grpcStatusCode,
  }) {
    return NetworkCallEntry(
      id: 'x',
      startTime: DateTime.utc(2026, 7, 15, 12),
      method: method,
      uri: Uri.parse(url),
      requestHeaders: const <String, String>{},
      requestBody: CapturedBody.none,
      responseHeaders: const <String, String>{},
      responseBody: CapturedBody.none,
      statusCode: 200,
      status: JalaCallStatus.success,
      client: client,
      operationName: operationName,
      operationType: operationType,
      rpcKind: rpcKind,
      grpcStatusCode: grpcStatusCode,
    );
  }

  Future<void> pumpTile(WidgetTester tester, NetworkCallEntry e) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: JalaCallListTile(entry: e))),
    );
  }

  testWidgets(
    'a plain HTTP entry shows the path as title, host as subtitle, and '
    'the HTTP method chip',
    (WidgetTester tester) async {
      await pumpTile(
        tester,
        entry(method: 'POST', url: 'https://api.example.com/users/42'),
      );
      await tester.pump();

      expect(find.text('/users/42'), findsOneWidget);
      expect(find.text('api.example.com'), findsOneWidget);
      expect(find.text('POST'), findsOneWidget);
    },
  );

  testWidgets(
    'path title includes the query string when present',
    (WidgetTester tester) async {
      await pumpTile(
        tester,
        entry(
          url: 'https://api.example.com/users?page=2&limit=10',
        ),
      );
      await tester.pump();

      expect(find.text('/users?page=2&limit=10'), findsOneWidget);
      expect(find.text('api.example.com'), findsOneWidget);
    },
  );

  testWidgets(
    'a GraphQL entry shows operationName as title and QUERY as the chip',
    (WidgetTester tester) async {
      await pumpTile(
        tester,
        entry(
          method: 'POST',
          url: 'https://api.example.com/graphql',
          operationName: 'GetUser',
          operationType: 'query',
        ),
      );
      await tester.pump();

      expect(find.text('GetUser'), findsOneWidget);
      expect(find.text('QUERY'), findsOneWidget);
      expect(find.text('POST'), findsNothing);
      expect(
        find.text('api.example.com/graphql'),
        findsOneWidget,
        reason: 'host + path move to the secondary line for GraphQL entries',
      );
    },
  );

  testWidgets(
    'a GraphQL mutation shows MUTATION as the uppercased chip',
    (WidgetTester tester) async {
      await pumpTile(
        tester,
        entry(operationName: 'CreateUser', operationType: 'mutation'),
      );
      await tester.pump();

      expect(find.text('CreateUser'), findsOneWidget);
      expect(find.text('MUTATION'), findsOneWidget);
    },
  );

  testWidgets(
    'a GraphQL entry with no operationType falls back to the HTTP method '
    'chip',
    (WidgetTester tester) async {
      await pumpTile(
        tester,
        entry(method: 'POST', operationName: 'GetUser', operationType: null),
      );
      await tester.pump();

      expect(find.text('GetUser'), findsOneWidget);
      expect(find.text('POST'), findsOneWidget);
    },
  );

  group('gRPC entries (Track G G3)', () {
    NetworkCallEntry grpcEntry({
      int grpcStatusCode = 0,
      String rpcKind = 'unary',
    }) => entry(
      method: 'POST',
      url: 'https://api.example.com/routeguide.RouteGuide/GetFeature',
      client: 'grpc',
      operationName: 'GetFeature',
      rpcKind: rpcKind,
      grpcStatusCode: grpcStatusCode,
    );

    testWidgets('shows service/method and the RPC kind chip', (
      WidgetTester tester,
    ) async {
      await pumpTile(tester, grpcEntry());

      expect(find.text('routeguide.RouteGuide/GetFeature'), findsOneWidget);
      expect(find.text('UNARY'), findsOneWidget);
      // Not the HTTP method — every gRPC call is a POST, which tells the
      // developer nothing.
      expect(find.text('POST'), findsNothing);
    });

    testWidgets('shows the gRPC status name, not the HTTP code', (
      WidgetTester tester,
    ) async {
      await pumpTile(tester, grpcEntry(grpcStatusCode: 5));

      expect(find.text('NOT_FOUND'), findsOneWidget);
      expect(find.text('200'), findsNothing);
    });

    testWidgets('a failed RPC is not coloured as a success', (
      WidgetTester tester,
    ) async {
      // Regression guard: a gRPC failure rides on an HTTP 200, so colouring
      // by statusCode alone paints every NOT_FOUND green.
      await pumpTile(tester, grpcEntry(grpcStatusCode: 5));
      final Text failed = tester.widget<Text>(find.text('NOT_FOUND'));

      await pumpTile(tester, grpcEntry());
      final Text ok = tester.widget<Text>(find.text('OK'));

      expect(failed.style?.color, isNot(ok.style?.color));
    });

    testWidgets('a plain HTTP entry keeps its method and code', (
      WidgetTester tester,
    ) async {
      await pumpTile(tester, entry());

      expect(find.text('GET'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
    });
  });
}
