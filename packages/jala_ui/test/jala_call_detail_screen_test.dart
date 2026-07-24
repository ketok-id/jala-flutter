import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);
  tearDown(JalaBinding.resetForTesting);

  testWidgets('Compare with… opens the diff screen for the picked call', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(
      binding.bus,
      'call-1',
      url: 'https://api.example.com/one',
      statusCode: 200,
    );
    emitCompletedCall(
      binding.bus,
      'call-2',
      url: 'https://api.example.com/two',
      statusCode: 404,
    );
    await flush();

    await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'call-1'));
    await pumpJalaSettle(tester);

    await tester.tap(find.byIcon(Icons.compare_arrows));
    await pumpJalaSettle(tester);
    expect(find.text('Compare with…'), findsOneWidget);

    await tester.tap(find.textContaining('/two'));
    await pumpJalaSettle(tester);

    expect(find.byType(JalaCallDiffScreen), findsOneWidget);
    expect(find.textContaining('200  →  404'), findsOneWidget);
  });

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

    // Cookie/auth headers are collapsed under Sensitive by default.
    expect(find.text('authorization'), findsNothing);
    await tester.tap(
      find.textContaining('Show 1 sensitive'),
    );
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

  // --- Subscription payload timeline (E3) ---------------------------------

  testWidgets(
    'Response tab renders a subscription payload timeline, opens a payload '
    'on tap, and shows the trimmed-count note',
    (WidgetTester tester) async {
      JalaBinding.instance.initialize(
        config: JalaConfig(enabled: true, maxSubscriptionPayloads: 2),
      );
      final JalaBinding binding = JalaBinding.instance;
      emitPendingRequest(
        binding.bus,
        'sub-1',
        method: 'POST',
        url: 'https://api.example.com/graphql',
        operationName: 'OnTick',
        operationType: 'subscription',
      );
      emitSubscriptionPayload(binding.bus, 'sub-1', seq: 0, data: '{"tick":0}');
      emitSubscriptionPayload(binding.bus, 'sub-1', seq: 1, data: '{"tick":1}');
      emitSubscriptionPayload(binding.bus, 'sub-1', seq: 2, data: '{"tick":2}');
      await flush();

      await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'sub-1'));
      await pumpJalaSettle(tester);

      await tester.tap(find.text('Response'));
      await pumpJalaSettle(tester);

      expect(find.text('Subscription payloads'), findsOneWidget);
      // Ring-capped at 2: the oldest payload (seq 0) fell out.
      expect(find.textContaining('Showing last 2 of 3 payloads'), findsOneWidget);
      expect(find.text('{"tick":1}'), findsOneWidget);
      expect(find.text('{"tick":2}'), findsOneWidget);
      expect(find.text('{"tick":0}'), findsNothing);

      await tester.tap(find.text('{"tick":2}'));
      await pumpJalaSettle(tester);

      expect(find.text('Payload #1'), findsOneWidget);
    },
  );

  testWidgets(
    'Response tab has no subscription payload timeline for a plain call',
    (WidgetTester tester) async {
      final JalaBinding binding = initJalaBinding();
      emitCompletedCall(binding.bus, 'plain-3');
      await flush();

      await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'plain-3'));
      await pumpJalaSettle(tester);

      await tester.tap(find.text('Response'));
      await pumpJalaSettle(tester);

      expect(find.text('Subscription payloads'), findsNothing);
    },
  );

  // --- Imported entries (E3) -----------------------------------------------

  testWidgets(
    'imported entries disable Replay/Mock this/Edit & resend with an '
    'explanatory tooltip',
    (WidgetTester tester) async {
      final JalaBinding binding = initJalaBinding();
      emitCompletedCall(binding.bus, 'orig-1', method: 'GET', statusCode: 200);
      await flush();
      final JalaSession session = JalaSessionCodec.decode(
        JalaSessionCodec.encode(binding.store),
      );
      binding.store.importSession(session);
      await flush();

      await pumpJalaApp(tester, const JalaCallDetailScreen(entryId: 'orig-1'));
      await pumpJalaSettle(tester);

      final FilledButton replayButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Replay'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(replayButton.onPressed, isNull);
      final Tooltip replayTooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.text('Replay'),
          matching: find.byType(Tooltip),
        ),
      );
      expect(replayTooltip.message, contains("can't be replayed"));

      final TextButton mockButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Mock this'),
          matching: find.byType(TextButton),
        ),
      );
      expect(mockButton.onPressed, isNull);
      final Tooltip mockTooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.text('Mock this'),
          matching: find.byType(Tooltip),
        ),
      );
      expect(mockTooltip.message, contains("can't be mocked"));

      final TextButton editButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Edit & resend'),
          matching: find.byType(TextButton),
        ),
      );
      expect(editButton.onPressed, isNull);
      final Tooltip editTooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.text('Edit & resend'),
          matching: find.byType(Tooltip),
        ),
      );
      expect(editTooltip.message, contains("can't be edited"));
    },
  );
}
