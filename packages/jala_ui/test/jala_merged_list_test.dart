import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

/// D4 merged-list coverage: network + WS entries interleaved
/// chronologically in `JalaInspectorScreen`, WS tiles updating live, and
/// `is:ws`/`is:graphql` filtering through the real filter engine.
void main() {
  setUpAll(configureJalaUiTests);
  tearDown(JalaBinding.resetForTesting);

  Color wsDotColor(WidgetTester tester) {
    final Iterable<Container> containers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(JalaWsListTile),
        matching: find.byType(Container),
      ),
    );
    for (final Container container in containers) {
      final Decoration? decoration = container.decoration;
      if (decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color != null) {
        return decoration.color!;
      }
    }
    fail('No status dot found inside JalaWsListTile');
  }

  testWidgets(
    'interleaves network and WS entries chronologically, newest first',
    (WidgetTester tester) async {
      final JalaBinding binding = initJalaBinding();
      emitCompletedCall(
        binding.bus,
        'old-call',
        url: 'https://api.example.com/oldest',
        startTime: DateTime.utc(2026, 7, 15, 12, 0, 0),
      );
      emitWsConnect(
        binding.bus,
        'ws-mid',
        url: 'wss://echo.example.com/socket',
        timestamp: DateTime.utc(2026, 7, 15, 12, 0, 30),
      );
      emitCompletedCall(
        binding.bus,
        'new-call',
        url: 'https://api.example.com/newest',
        startTime: DateTime.utc(2026, 7, 15, 12, 1, 0),
      );
      await flush();

      await pumpJalaApp(tester, const JalaInspectorScreen());
      await pumpJalaSettle(tester);

      expect(find.byType(JalaCallListTile), findsNWidgets(2));
      expect(find.byType(JalaWsListTile), findsOneWidget);

      final double newestY = tester.getTopLeft(find.text('/newest')).dy;
      final double wsY = tester.getTopLeft(find.byType(JalaWsListTile)).dy;
      final double oldestY = tester.getTopLeft(find.text('/oldest')).dy;
      expect(
        newestY,
        lessThan(wsY),
        reason: 'the newest network call renders above the WS connection',
      );
      expect(
        wsY,
        lessThan(oldestY),
        reason: 'the WS connection renders above the oldest network call',
      );
    },
  );

  testWidgets(
    'WS tile shows the WS chip, status color, and frame count, updating '
    'live as frames and close events arrive',
    (WidgetTester tester) async {
      final JalaBinding binding = initJalaBinding();
      emitWsConnect(binding.bus, 'ws-1');
      emitWsFrame(binding.bus, 'ws-1', data: 'ping');
      await flush();

      await pumpJalaApp(tester, const JalaInspectorScreen());
      await pumpJalaSettle(tester);

      expect(find.text('WS'), findsOneWidget);
      expect(find.text('open'), findsOneWidget);
      expect(find.textContaining('1 frame'), findsOneWidget);
      expect(
        wsDotColor(tester),
        JalaTheme.wsStatusColorFor(WsConnectionStatus.open),
      );

      emitWsFrame(binding.bus, 'ws-1', data: 'pong');
      await flush();
      await pumpJalaSettle(tester);

      expect(find.textContaining('2 frames'), findsOneWidget);

      emitWsClose(binding.bus, 'ws-1', code: 1000, reason: 'done');
      await flush();
      await pumpJalaSettle(tester);

      expect(find.text('closed'), findsOneWidget);
      expect(
        wsDotColor(tester),
        JalaTheme.wsStatusColorFor(WsConnectionStatus.closed),
      );
    },
  );

  testWidgets('an errored WS connection shows the error status color', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitWsConnect(binding.bus, 'ws-err');
    emitWsError(binding.bus, 'ws-err', errorMessage: 'connection reset');
    await flush();

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);

    expect(find.text('error'), findsOneWidget);
    expect(
      wsDotColor(tester),
      JalaTheme.wsStatusColorFor(WsConnectionStatus.error),
    );
  });

  testWidgets('typing is:ws narrows the merged list to WS entries only', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'plain', url: 'https://api.example.com/x');
    emitCompletedCall(
      binding.bus,
      'gql',
      method: 'POST',
      url: 'https://api.example.com/graphql',
      operationName: 'GetUser',
      operationType: 'query',
    );
    emitWsConnect(binding.bus, 'ws-1');
    await flush();

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);
    expect(find.byType(JalaCallListTile), findsNWidgets(2));
    expect(find.byType(JalaWsListTile), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'is:ws');
    await tester.pump(const Duration(milliseconds: 200));
    await pumpJalaSettle(tester);

    expect(find.byType(JalaWsListTile), findsOneWidget);
    expect(find.byType(JalaCallListTile), findsNothing);
  });

  testWidgets(
    'typing is:graphql narrows the merged list to GraphQL entries only',
    (WidgetTester tester) async {
      final JalaBinding binding = initJalaBinding();
      emitCompletedCall(binding.bus, 'plain', url: 'https://api.example.com/x');
      emitCompletedCall(
        binding.bus,
        'gql',
        method: 'POST',
        url: 'https://api.example.com/graphql',
        operationName: 'GetUser',
        operationType: 'query',
      );
      emitWsConnect(binding.bus, 'ws-1');
      await flush();

      await pumpJalaApp(tester, const JalaInspectorScreen());
      await pumpJalaSettle(tester);

      await tester.enterText(find.byType(TextField).first, 'is:graphql');
      await tester.pump(const Duration(milliseconds: 200));
      await pumpJalaSettle(tester);

      expect(find.byType(JalaCallListTile), findsOneWidget);
      expect(find.text('GetUser'), findsOneWidget);
      expect(find.byType(JalaWsListTile), findsNothing);
      expect(find.text('/x'), findsNothing);
    },
  );

  testWidgets('tapping a WS tile opens the WS detail screen', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitWsConnect(binding.bus, 'ws-1', url: 'wss://echo.example.com/socket');
    await flush();

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);

    await tester.tap(find.byType(JalaWsListTile));
    await pumpJalaSettle(tester);

    expect(find.byType(JalaWsDetailScreen), findsOneWidget);
    expect(find.text('wss://echo.example.com/socket'), findsOneWidget);
  });

  testWidgets('Clear removes WS entries and restores the empty state', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitWsConnect(binding.bus, 'ws-1');
    await flush();

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);
    expect(find.byType(JalaWsListTile), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await pumpJalaSettle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await pumpJalaSettle(tester);

    expect(find.byType(JalaWsListTile), findsNothing);
    expect(find.text('No network calls captured yet.'), findsOneWidget);
  });
}
