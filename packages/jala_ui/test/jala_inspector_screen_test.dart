import 'package:flutter/material.dart';
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
}
