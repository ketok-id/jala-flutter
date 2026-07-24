// Demo driver for Track F: drives the call-diff and cURL-import flows on a
// real device/simulator while the screen is recorded. Not a correctness test
// (the widget tests in packages/jala_ui cover that) — assertions are minimal
// and the pauses are for the viewer. Mirrors demo_driver_test.dart.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jala_example/main.dart' as app;

Future<void> pause(WidgetTester tester, int ms) async {
  await tester.pump();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('track F: compare two calls + import cURL', (
    WidgetTester tester,
  ) async {
    unawaited(app.main());
    await tester.pumpAndSettle();
    await pause(tester, 1200);

    // Fire a GET and a POST so there are two JSON responses to diff.
    await tester.tap(find.text('GET json'));
    await pause(tester, 1200);
    await tester.tap(find.text('POST json'));
    await pause(tester, 2800); // let both land

    // Open the inspector via the bubble.
    await tester.tap(find.text('J'));
    await tester.pumpAndSettle();
    await pause(tester, 1400);

    // --- Compare flow: open the GET call, compare with the POST ---
    // Note: 'postman-echo.com' contains the substring '/post', so pick by the
    // exact 'POST /post' picker label rather than textContaining('/post').
    await tester.tap(find.textContaining('hello=jala').first);
    await tester.pumpAndSettle();
    await pause(tester, 1400);

    await tester.tap(find.byIcon(Icons.compare_arrows));
    await tester.pumpAndSettle();
    await pause(tester, 1400); // "Compare with…" picker

    await tester.tap(find.text('POST /post'));
    await tester.pumpAndSettle();
    await pause(tester, 3000); // the diff screen — add/remove/change coloring

    // Back to the list.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await pause(tester, 600);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await pause(tester, 1000);

    // --- Import cURL flow ---
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await pause(tester, 900);
    await tester.tap(find.text('Import cURL…'));
    await tester.pumpAndSettle();
    await pause(tester, 900);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'curl -X POST https://api.example.com/orders '
      "-H 'Content-Type: application/json' "
      "-d '{\"item\":\"jala\",\"qty\":2}'",
    );
    await pause(tester, 1600);
    await tester.tap(find.text('Open in composer'));
    await tester.pumpAndSettle();
    await pause(tester, 3000); // the composer, prefilled from the curl

    expect(find.textContaining('api.example.com'), findsWidgets);
  });
}
