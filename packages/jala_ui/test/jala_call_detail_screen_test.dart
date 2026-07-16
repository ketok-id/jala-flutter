import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);
  tearDown(JalaBinding.resetForTesting);

  testWidgets('shows the redacted header mask on the Request tab', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(
      binding.bus,
      'call-1',
      requestHeaders: const <String, String>{
        'authorization': JalaRedactor.mask,
        'accept': 'application/json',
      },
    );
    await flush();

    await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'call-1'));
    await pumpJalaSettle(tester);

    await tester.tap(find.text('Request'));
    await pumpJalaSettle(tester);

    expect(find.text('authorization'), findsOneWidget);
    expect(find.text(JalaRedactor.mask), findsOneWidget);
  });

  testWidgets('JSON tree expands a nested node on tap', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(
      binding.bus,
      'call-2',
      responseHeaders: const <String, String>{
        'content-type': 'application/json',
      },
      responseBody: CapturedBody.capture(<String, dynamic>{
        'user': <String, dynamic>{
          'name': 'Ada',
          'roles': <String>['admin', 'dev'],
        },
      }, contentType: 'application/json'),
    );
    await flush();

    await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'call-2'));
    await pumpJalaSettle(tester);

    await tester.tap(find.text('Response'));
    await pumpJalaSettle(tester);

    expect(find.text('user'), findsOneWidget);
    expect(find.textContaining('name'), findsNothing);

    await tester.tap(find.text('user'));
    await pumpJalaSettle(tester);

    expect(find.textContaining('name'), findsOneWidget);
  });

  testWidgets('Copy cURL puts a curl command on the clipboard', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'call-3', method: 'POST');
    await flush();

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final Map<Object?, Object?> args =
              call.arguments as Map<Object?, Object?>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'call-3'));
    await pumpJalaSettle(tester);

    await tester.tap(find.widgetWithText(TextButton, 'cURL'));
    await pumpJalaSettle(tester);

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('curl -X'));
  });

  testWidgets('shows a fallback when the entry is no longer available', (
    WidgetTester tester,
  ) async {
    initJalaBinding();

    await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'missing'));
    await pumpJalaSettle(tester);

    expect(find.text('This call is no longer available.'), findsOneWidget);
  });

  testWidgets('Overview shows live transferred bytes for a pending call, and '
      'updates as progress arrives', (WidgetTester tester) async {
    final JalaBinding binding = initJalaBinding();
    emitPendingRequest(binding.bus, 'call-progress');
    await flush();

    await pumpJalaApp(
      tester,
      const JalaCallDetailScreen(entryId: 'call-progress'),
    );
    await pumpJalaSettle(tester);

    expect(find.text('Transferred'), findsNothing);

    emitProgress(
      binding.bus,
      'call-progress',
      receivedBytes: 512,
      receivedTotal: 2048,
    );
    await flush();
    await pumpJalaSettle(tester);

    expect(find.text('Transferred'), findsOneWidget);
    expect(find.textContaining('512 B / 2.0 KB'), findsOneWidget);

    emitProgress(
      binding.bus,
      'call-progress',
      receivedBytes: 2048,
      receivedTotal: 2048,
    );
    await flush();
    await pumpJalaSettle(tester);

    expect(find.textContaining('2.0 KB / 2.0 KB'), findsOneWidget);
  });

  // --- GraphQL detail (D4) ------------------------------------------------

  /// Emits a completed GraphQL POST whose request body follows the
  /// `{operationName, query, variables}` shape `jala_graphql` captures.
  void emitGraphQlCall(
    JalaBinding binding,
    String id, {
    Map<String, dynamic>? variables,
  }) {
    emitCompletedCall(
      binding.bus,
      id,
      method: 'POST',
      url: 'https://api.example.com/graphql',
      operationName: 'GetUser',
      operationType: 'query',
      requestBody: CapturedBody.capture(<String, dynamic>{
        'operationName': 'GetUser',
        'query': r'query GetUser($id: ID!) { user(id: $id) { name } }',
        'variables': variables,
      }, contentType: 'application/json'),
    );
  }

  testWidgets(
    'Request tab shows Query and Variables sections for a GraphQL entry',
    (WidgetTester tester) async {
      final JalaBinding binding = initJalaBinding();
      emitGraphQlCall(
        binding,
        'gql-1',
        variables: <String, dynamic>{'id': '42'},
      );
      await flush();

      await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'gql-1'));
      await pumpJalaSettle(tester);

      await tester.tap(find.text('Request'));
      await pumpJalaSettle(tester);

      expect(find.text('Query'), findsOneWidget);
      expect(
        find.text(r'query GetUser($id: ID!) { user(id: $id) { name } }'),
        findsOneWidget,
      );
      expect(find.text('Variables'), findsOneWidget);
      expect(find.byType(JalaJsonTree), findsOneWidget);
      // Root map is expanded by default, so the variable leaf is visible.
      expect(find.textContaining('id: 42'), findsOneWidget);
      // The raw body view is replaced by the two sections.
      expect(find.byType(JalaBodyView), findsNothing);
    },
  );

  testWidgets(
    'Request tab shows an empty state when a GraphQL entry has no variables',
    (WidgetTester tester) async {
      final JalaBinding binding = initJalaBinding();
      emitGraphQlCall(binding, 'gql-2');
      await flush();

      await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'gql-2'));
      await pumpJalaSettle(tester);

      await tester.tap(find.text('Request'));
      await pumpJalaSettle(tester);

      expect(find.text('Query'), findsOneWidget);
      expect(find.text('Variables'), findsOneWidget);
      expect(find.text('No variables'), findsOneWidget);
      expect(find.byType(JalaJsonTree), findsNothing);
    },
  );

  testWidgets('Request tab keeps the plain body view for a non-GraphQL entry', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(
      binding.bus,
      'plain-1',
      method: 'POST',
      requestBody: CapturedBody.capture(
        '{"query":"looks graphql-ish but has no operation metadata"}',
        contentType: 'application/json',
      ),
    );
    await flush();

    await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'plain-1'));
    await pumpJalaSettle(tester);

    await tester.tap(find.text('Request'));
    await pumpJalaSettle(tester);

    expect(find.byType(JalaBodyView), findsOneWidget);
    expect(find.text('Query'), findsNothing);
    expect(find.text('Variables'), findsNothing);
  });

  testWidgets('Overview shows the Operation row for a GraphQL entry', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitGraphQlCall(binding, 'gql-3', variables: <String, dynamic>{'id': '42'});
    await flush();

    await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'gql-3'));
    await pumpJalaSettle(tester);

    expect(find.text('Operation'), findsOneWidget);
    expect(find.text('GetUser (query)'), findsOneWidget);
  });

  testWidgets('Overview has no Operation row for a plain HTTP entry', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'plain-2');
    await flush();

    await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'plain-2'));
    await pumpJalaSettle(tester);

    expect(find.text('Operation'), findsNothing);
  });

  testWidgets('GraphQL entries keep the cURL/Dart/HAR/Replay actions', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitGraphQlCall(binding, 'gql-4');
    await flush();

    await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'gql-4'));
    await pumpJalaSettle(tester);

    expect(find.text('cURL'), findsOneWidget);
    expect(find.text('Dart'), findsOneWidget);
    expect(find.text('HAR'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
  });
}
