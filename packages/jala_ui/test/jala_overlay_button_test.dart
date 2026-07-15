import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

void main() {
  tearDown(JalaBinding.resetForTesting);

  testWidgets('renders the J glyph and invokes onTap', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: <Widget>[
            JalaOverlayButton(onTap: () => tapped = true),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('J'), findsOneWidget);

    await tester.tap(find.text('J'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
