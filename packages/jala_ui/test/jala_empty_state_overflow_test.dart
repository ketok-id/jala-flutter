// Regression test found on-device: exporting a session puts JSON on the
// clipboard, a tester pastes it into the filter field, and the "No calls
// match …" empty state — which echoes the filter verbatim — overflowed the
// screen by 313px. The message is not length-bounded, so it must clamp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);

  tearDown(() async {
    await JalaBinding.resetForTesting();
  });

  testWidgets('a very long filter does not overflow the empty state', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'c1');
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: JalaInspectorScreen()));
    await tester.pumpAndSettle();

    // Roughly what a pasted session export looks like.
    final String pasted =
        '{"format":"jala-session","version":1,"entries":[${'x' * 2000}]}';
    await tester.enterText(find.byType(TextField).first, pasted);
    await tester.pumpAndSettle();

    expect(find.textContaining('No calls match'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'the empty state must clamp the echoed filter — an unbounded '
          'Text here overflowed the Column by 313px on a real device',
    );
  });
}
