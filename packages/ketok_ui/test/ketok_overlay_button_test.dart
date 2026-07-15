import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ketok_core/ketok_core.dart';
import 'package:ketok_ui/ketok_ui.dart';

void main() {
  tearDown(KetokBinding.resetForTesting);

  testWidgets('renders the K glyph and invokes onTap', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: <Widget>[
            KetokOverlayButton(onTap: () => tapped = true),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('K'), findsOneWidget);

    await tester.tap(find.text('K'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
