// Track F smoke on a real device/simulator: sample cURL/HAR import and
// compare-last-two from the QA rig. No live network required for these
// paths — the samples are inlined. Prints step markers for hang diagnosis.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jala/jala.dart';
import 'package:jala_example/main.dart' as app;

void step(String msg) {
  // ignore: avoid_print
  print('TRACK_F_SMOKE: $msg');
}

Future<void> pause(WidgetTester tester, int ms) async {
  await tester.pump();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await tester.pump();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F3 sample cURL / HAR import + compare last two', (
    WidgetTester tester,
  ) async {
    step('1 launch app');
    unawaited(app.main());
    await tester.pumpAndSettle();
    await pause(tester, 800);

    expect(find.text('Jala QA Rig'), findsOneWidget);

    // --- Import HAR (sample) ---
    step('2 Import HAR (sample)');
    await scrollTo(tester, find.text('Import HAR (sample)'));
    await tester.tap(find.text('Import HAR (sample)'));
    await tester.pumpAndSettle();
    await pause(tester, 600);

    expect(JalaBinding.instance.store.entries, hasLength(2));
    expect(JalaBinding.instance.store.isViewingImport, isTrue);
    expect(find.textContaining('Imported HAR'), findsOneWidget);
    step('3 HAR imported (2 entries, viewing import)');

    // Dismiss snackbar so it does not intercept the next tap.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
      tester.element(find.text('Jala QA Rig')),
    );
    messenger.hideCurrentSnackBar();
    await tester.pumpAndSettle();

    // --- Compare last two ---
    step('4 Compare last two');
    await scrollTo(tester, find.text('Compare last two'));
    await tester.tap(find.text('Compare last two'));
    await tester.pumpAndSettle();
    await pause(tester, 1200);

    expect(find.byType(JalaCallDiffScreen), findsOneWidget);
    expect(find.text('Compare calls'), findsOneWidget);
    // Sample HAR bodies differ by the added "qty" field.
    expect(find.textContaining('qty'), findsWidgets);
    step('5 diff screen open');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await pause(tester, 400);

    // --- Import cURL (sample) ---
    step('6 Import cURL (sample)');
    await scrollTo(tester, find.text('Import cURL (sample)'));
    await tester.tap(find.text('Import cURL (sample)'));
    await tester.pumpAndSettle();
    await pause(tester, 1200);

    expect(find.byType(JalaRequestComposerScreen), findsOneWidget);
    expect(find.textContaining('api.example.com/orders'), findsWidgets);
    step('7 composer prefilled from sample cURL — done');
  });
}
