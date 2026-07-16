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
}
