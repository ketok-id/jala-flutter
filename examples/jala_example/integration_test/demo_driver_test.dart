// Demo driver: performs the README-GIF interaction sequence on a real
// device/simulator while the screen is being recorded. Not a correctness
// test — assertions are minimal; pacing pauses are for the viewer.
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

  testWidgets('gif demo flow', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    await pause(tester, 1500);

    // Fire a mix of requests.
    for (final String button in <String>['GET json', 'POST json', '404']) {
      await tester.tap(find.text(button));
      await pause(tester, 900);
    }
    // Let responses land.
    await pause(tester, 2500);

    // Open the inspector via the bubble.
    await tester.tap(find.text('J'));
    await tester.pumpAndSettle();
    await pause(tester, 1600);

    // Filter: status 4xx only.
    await tester.enterText(find.byType(TextField).first, 's:4xx');
    await pause(tester, 1800);

    // Clear filter, open the 404 call.
    await tester.enterText(find.byType(TextField).first, '');
    await pause(tester, 800);
    await tester.tap(find.text('/status/404').first);
    await tester.pumpAndSettle();
    await pause(tester, 1400);

    // Request tab — shows the redacted Authorization header.
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    await pause(tester, 1800);

    // Replay it.
    await tester.tap(find.text('Replay'));
    await pause(tester, 2500);

    // Back to the list — replayed call visible at top.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await pause(tester, 2500);

    expect(find.text('/status/404'), findsWidgets);
  });
}
