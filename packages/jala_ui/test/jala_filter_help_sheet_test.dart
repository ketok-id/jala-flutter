import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);

  Future<void> pumpSheet(WidgetTester tester) {
    // The sheet's content only fits within the default 800x600 test
    // surface when hosted by the real scrollable modal bottom sheet (see
    // JalaInspectorScreen._openHelp); grow the surface here so a plain
    // Scaffold host doesn't trip a RenderFlex overflow in this test.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: JalaFilterHelpSheet()),
      ),
    );
  }

  testWidgets('lists the GraphQL and WS filter terms', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);
    await tester.pump();

    expect(
      find.textContaining('op:', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('is:graphql', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('is:subscription', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('is:ws', findRichText: true), findsOneWidget);
  });

  testWidgets('still lists the pre-existing terms', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);
    await tester.pump();

    expect(
      find.textContaining('method: / m:', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('is:replay', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('is:mocked', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('does not overflow under a longer locale on a short screen', (
    WidgetTester tester,
  ) async {
    // Found on device: Indonesian runs longer than English and overflowed
    // this sheet by 4px. English fit only by luck — the Column was not
    // scrollable at all. A deliberately short viewport reproduces it
    // without depending on which locale is longest today.
    tester.view.physicalSize = const Size(1080, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: JalaFilterHelpSheet()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
