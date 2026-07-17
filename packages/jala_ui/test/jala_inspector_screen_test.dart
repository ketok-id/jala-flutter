import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);
  tearDown(JalaBinding.resetForTesting);

  testWidgets('renders tiles with method chip and status code', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(
      binding.bus,
      'a',
      method: 'GET',
      url: 'https://api.example.com/ok',
      statusCode: 200,
    );
    emitCompletedCall(
      binding.bus,
      'b',
      method: 'POST',
      url: 'https://api.example.com/missing',
      statusCode: 404,
    );
    await flush();

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);

    expect(find.byType(JalaCallListTile), findsNWidgets(2));
    expect(find.text('GET'), findsOneWidget);
    expect(find.text('POST'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    expect(find.text('404'), findsOneWidget);
  });

  testWidgets('typing s:4xx in the filter field narrows the list', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(
      binding.bus,
      'a',
      method: 'GET',
      url: 'https://api.example.com/ok',
      statusCode: 200,
    );
    emitCompletedCall(
      binding.bus,
      'b',
      method: 'POST',
      url: 'https://api.example.com/missing',
      statusCode: 404,
    );
    await flush();

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);
    expect(find.byType(JalaCallListTile), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, 's:4xx');
    // Past the ~150ms debounce.
    await tester.pump(const Duration(milliseconds: 200));
    await pumpJalaSettle(tester);

    expect(find.byType(JalaCallListTile), findsOneWidget);
    expect(find.text('/missing'), findsOneWidget);
    expect(find.text('/ok'), findsNothing);
  });

  testWidgets('shows an empty state when nothing has been captured yet', (
    WidgetTester tester,
  ) async {
    initJalaBinding();

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);

    expect(find.text('No network calls captured yet.'), findsOneWidget);
  });

  testWidgets('shows a filtered-empty state naming the active query', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'a', method: 'GET', statusCode: 200);
    await flush();

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);

    await tester.enterText(find.byType(TextField).first, 'method:delete');
    await tester.pump(const Duration(milliseconds: 200));
    await pumpJalaSettle(tester);

    expect(find.textContaining('No calls match'), findsOneWidget);
  });

  // --- Session export/import (E3) -----------------------------------------

  testWidgets('Export session copies versioned JSON with an entry count', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'a', method: 'GET', statusCode: 200);
    emitCompletedCall(binding.bus, 'b', method: 'POST', statusCode: 201);
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

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await pumpJalaSettle(tester);
    await tester.tap(find.text('Export session'));
    await pumpJalaSettle(tester);

    expect(clipboardText, isNotNull);
    final Map<String, dynamic> envelope =
        jsonDecode(clipboardText!) as Map<String, dynamic>;
    expect(envelope['format'], JalaSessionCodec.formatMarker);
    expect((envelope['entries'] as List).length, 2);
    expect(find.textContaining('2 entries'), findsOneWidget);
  });

  testWidgets(
    'Import session renders imported entries, shows the import banner, and '
    'disables replay on the detail screen',
    (WidgetTester tester) async {
      final JalaBinding binding = initJalaBinding();
      emitCompletedCall(binding.bus, 'orig', method: 'GET', statusCode: 200);
      await flush();
      final String sessionJson = JalaSessionCodec.encode(binding.store);
      binding.store.clear();
      await flush();

      await pumpJalaApp(tester, const JalaInspectorScreen());
      await pumpJalaSettle(tester);

      await tester.tap(find.byIcon(Icons.more_vert));
      await pumpJalaSettle(tester);
      await tester.tap(find.text('Import session'));
      await pumpJalaSettle(tester);

      expect(find.text('Import session'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        sessionJson,
      );
      await pumpJalaSettle(tester);
      await tester.tap(find.text('Import'));
      await pumpJalaSettle(tester);

      expect(binding.store.isViewingImport, isTrue);
      expect(
        find.textContaining('Imported session (1 entry)'),
        findsOneWidget,
      );
      expect(find.byType(JalaCallListTile), findsOneWidget);

      await tester.tap(find.byType(JalaCallListTile));
      await pumpJalaSettle(tester);

      final Tooltip replayTooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.text('Replay'),
          matching: find.byType(Tooltip),
        ),
      );
      expect(replayTooltip.message, contains("can't be replayed"));
      final FilledButton replayButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Replay'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(replayButton.onPressed, isNull);
    },
  );

  testWidgets('Import session shows an inline error for malformed input', (
    WidgetTester tester,
  ) async {
    initJalaBinding();

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await pumpJalaSettle(tester);
    await tester.tap(find.text('Import session'));
    await pumpJalaSettle(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'not json at all',
    );
    await pumpJalaSettle(tester);
    await tester.tap(find.text('Import'));
    await pumpJalaSettle(tester);

    expect(find.textContaining('Malformed JSON'), findsOneWidget);
    // The dialog stayed open rather than crashing.
    expect(find.text('Import session'), findsOneWidget);
  });
}
