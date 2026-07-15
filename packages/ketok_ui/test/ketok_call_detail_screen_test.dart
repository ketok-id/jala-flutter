import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ketok_core/ketok_core.dart';
import 'package:ketok_ui/ketok_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureKetokUiTests);
  tearDown(KetokBinding.resetForTesting);

  testWidgets('shows the redacted header mask on the Request tab', (
    WidgetTester tester,
  ) async {
    final KetokBinding binding = initKetokBinding();
    emitCompletedCall(
      binding.bus,
      'call-1',
      requestHeaders: const <String, String>{
        'authorization': KetokRedactor.mask,
        'accept': 'application/json',
      },
    );
    await flush();

    await pumpKetokApp(
      tester,
      const KetokCallDetailScreen(entryId: 'call-1'),
    );
    await pumpKetokSettle(tester);

    await tester.tap(find.text('Request'));
    await pumpKetokSettle(tester);

    expect(find.text('authorization'), findsOneWidget);
    expect(find.text(KetokRedactor.mask), findsOneWidget);
  });

  testWidgets('JSON tree expands a nested node on tap', (
    WidgetTester tester,
  ) async {
    final KetokBinding binding = initKetokBinding();
    emitCompletedCall(
      binding.bus,
      'call-2',
      responseHeaders: const <String, String>{
        'content-type': 'application/json',
      },
      responseBody: CapturedBody.capture(
        <String, dynamic>{
          'user': <String, dynamic>{
            'name': 'Ada',
            'roles': <String>['admin', 'dev'],
          },
        },
        contentType: 'application/json',
      ),
    );
    await flush();

    await pumpKetokApp(
      tester,
      const KetokCallDetailScreen(entryId: 'call-2'),
    );
    await pumpKetokSettle(tester);

    await tester.tap(find.text('Response'));
    await pumpKetokSettle(tester);

    expect(find.text('user'), findsOneWidget);
    expect(find.textContaining('name'), findsNothing);

    await tester.tap(find.text('user'));
    await pumpKetokSettle(tester);

    expect(find.textContaining('name'), findsOneWidget);
  });

  testWidgets('Copy cURL puts a curl command on the clipboard', (
    WidgetTester tester,
  ) async {
    final KetokBinding binding = initKetokBinding();
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

    await pumpKetokApp(
      tester,
      const KetokCallDetailScreen(entryId: 'call-3'),
    );
    await pumpKetokSettle(tester);

    await tester.tap(find.widgetWithText(TextButton, 'cURL'));
    await pumpKetokSettle(tester);

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('curl -X'));
  });

  testWidgets('shows a fallback when the entry is no longer available', (
    WidgetTester tester,
  ) async {
    initKetokBinding();

    await pumpKetokApp(
      tester,
      const KetokCallDetailScreen(entryId: 'missing'),
    );
    await pumpKetokSettle(tester);

    expect(find.text('This call is no longer available.'), findsOneWidget);
  });
}
