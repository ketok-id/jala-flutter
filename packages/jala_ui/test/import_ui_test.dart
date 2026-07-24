import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);
  tearDown(JalaBinding.resetForTesting);

  Future<void> openMenuItem(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await pumpJalaSettle(tester);
    await tester.tap(find.text(label));
    await pumpJalaSettle(tester);
  }

  Finder dialogField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  testWidgets('Import HAR loads a pasted HAR document as an imported session', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'orig', method: 'GET', statusCode: 200);
    await flush();
    final String har = HarExporter.exportSession(binding.store.entries);
    binding.store.clear();
    await flush();

    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);

    await openMenuItem(tester, 'Import HAR…');
    expect(find.text('Import HAR'), findsOneWidget);

    await tester.enterText(dialogField(), har);
    await pumpJalaSettle(tester);
    await tester.tap(find.text('Import'));
    await pumpJalaSettle(tester);

    expect(binding.store.isViewingImport, isTrue);
    expect(find.byType(JalaCallListTile), findsOneWidget);
  });

  testWidgets('Import HAR shows an inline error for malformed input', (
    WidgetTester tester,
  ) async {
    initJalaBinding();
    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);

    await openMenuItem(tester, 'Import HAR…');
    await tester.enterText(dialogField(), '{not har');
    await pumpJalaSettle(tester);
    await tester.tap(find.text('Import'));
    await pumpJalaSettle(tester);

    // Dialog stays open with an error; nothing imported.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Malformed HAR'), findsOneWidget);
  });

  testWidgets('Import cURL opens the request composer prefilled', (
    WidgetTester tester,
  ) async {
    initJalaBinding();
    await pumpJalaApp(tester, const JalaInspectorScreen());
    await pumpJalaSettle(tester);

    await openMenuItem(tester, 'Import cURL…');
    expect(find.text('Import cURL'), findsOneWidget);

    await tester.enterText(
      dialogField(),
      "curl -X POST https://api.example.com/post "
      "-H 'Content-Type: application/json' -d '{\"a\":1}'",
    );
    await pumpJalaSettle(tester);
    await tester.tap(find.text('Open in composer'));
    await pumpJalaSettle(tester);

    // The composer screen is now on top, showing the parsed request.
    expect(find.byType(JalaRequestComposerScreen), findsOneWidget);
    expect(find.textContaining('api.example.com/post'), findsWidgets);
  });
}
