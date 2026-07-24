import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala/jala.dart';
import 'package:jala_example/main.dart';

void main() {
  tearDown(() async {
    Jala.resetControllerForTesting();
    await JalaBinding.resetForTesting();
  });

  testWidgets('example app renders QA buttons', (WidgetTester tester) async {
    Jala.initialize(config: JalaConfig(enabled: true));
    final Dio dio = Dio();
    await tester.pumpWidget(JalaOverlay(child: JalaExampleApp(dio: dio)));
    await tester.pump();

    expect(find.text('Jala QA Rig'), findsOneWidget);
    expect(find.text('GET json'), findsOneWidget);
    expect(find.text('J'), findsOneWidget);
  });

  testWidgets('Inspect deeper sample buttons import HAR and open compare', (
    WidgetTester tester,
  ) async {
    Jala.initialize(config: JalaConfig(enabled: true));
    final Dio dio = Dio();
    await tester.pumpWidget(JalaOverlay(child: JalaExampleApp(dio: dio)));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Import HAR (sample)'),
      200,
    );
    await tester.tap(find.text('Import HAR (sample)'));
    await tester.pumpAndSettle();

    expect(JalaBinding.instance.store.entries, hasLength(2));
    expect(JalaBinding.instance.store.isViewingImport, isTrue);
    expect(find.textContaining('Imported HAR'), findsOneWidget);

    // Dismiss the snackbar so it does not steal the next tap.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
      tester.element(find.text('Jala QA Rig')),
    );
    messenger.hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Compare last two'), 100);
    await tester.tap(find.text('Compare last two'));
    await tester.pumpAndSettle();

    expect(find.byType(JalaCallDiffScreen), findsOneWidget);
    expect(find.text('Compare calls'), findsOneWidget);
  });

  testWidgets('Import cURL sample opens the request composer', (
    WidgetTester tester,
  ) async {
    Jala.initialize(config: JalaConfig(enabled: true));
    final Dio dio = Dio();
    await tester.pumpWidget(JalaOverlay(child: JalaExampleApp(dio: dio)));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Import cURL (sample)'),
      200,
    );
    await tester.tap(find.text('Import cURL (sample)'));
    await tester.pumpAndSettle();

    expect(find.byType(JalaRequestComposerScreen), findsOneWidget);
    expect(find.textContaining('api.example.com/orders'), findsWidgets);
  });
}
