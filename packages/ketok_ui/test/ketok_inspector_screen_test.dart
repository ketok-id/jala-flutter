import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ketok_core/ketok_core.dart';
import 'package:ketok_ui/ketok_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureKetokUiTests);
  tearDown(KetokBinding.resetForTesting);

  testWidgets('renders tiles with method chip and status code', (
    WidgetTester tester,
  ) async {
    final KetokBinding binding = initKetokBinding();
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

    await pumpKetokApp(tester, const KetokInspectorScreen());
    await pumpKetokSettle(tester);

    expect(find.byType(KetokCallListTile), findsNWidgets(2));
    expect(find.text('GET'), findsOneWidget);
    expect(find.text('POST'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    expect(find.text('404'), findsOneWidget);
  });

  testWidgets('typing s:4xx in the filter field narrows the list', (
    WidgetTester tester,
  ) async {
    final KetokBinding binding = initKetokBinding();
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

    await pumpKetokApp(tester, const KetokInspectorScreen());
    await pumpKetokSettle(tester);
    expect(find.byType(KetokCallListTile), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, 's:4xx');
    // Past the ~150ms debounce.
    await tester.pump(const Duration(milliseconds: 200));
    await pumpKetokSettle(tester);

    expect(find.byType(KetokCallListTile), findsOneWidget);
    expect(find.text('/missing'), findsOneWidget);
    expect(find.text('/ok'), findsNothing);
  });

  testWidgets('shows an empty state when nothing has been captured yet', (
    WidgetTester tester,
  ) async {
    initKetokBinding();

    await pumpKetokApp(tester, const KetokInspectorScreen());
    await pumpKetokSettle(tester);

    expect(find.text('No network calls captured yet.'), findsOneWidget);
  });

  testWidgets('shows a filtered-empty state naming the active query', (
    WidgetTester tester,
  ) async {
    final KetokBinding binding = initKetokBinding();
    emitCompletedCall(binding.bus, 'a', method: 'GET', statusCode: 200);
    await flush();

    await pumpKetokApp(tester, const KetokInspectorScreen());
    await pumpKetokSettle(tester);

    await tester.enterText(find.byType(TextField).first, 'method:delete');
    await tester.pump(const Duration(milliseconds: 200));
    await pumpKetokSettle(tester);

    expect(find.textContaining('No calls match'), findsOneWidget);
  });
}
