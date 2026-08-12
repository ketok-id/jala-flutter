// Track I / I3: the throttle screen must say what the active mode covers,
// and expose mid-stream drop for socket mode.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);
  tearDown(() async => JalaBinding.resetForTesting());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: JalaThrottleScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('states adapter-only scope by default', (
    WidgetTester tester,
  ) async {
    initJalaBinding();
    await pump(tester);

    // "I set Slow 3G and my images still load" is the most common confusion
    // about this feature; the screen has to say so rather than let it read
    // as a bug.
    expect(find.textContaining('attached clients only'), findsOneWidget);
    expect(find.textContaining('Image.network'), findsOneWidget);
  });

  testWidgets('states full dart:io scope once socket mode is on', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    binding.throttleRegistry.socketModeActive = true;
    await pump(tester);

    expect(find.textContaining('all dart:io traffic'), findsOneWidget);
    expect(find.textContaining('attached clients only'), findsNothing);
  });

  testWidgets('custom profile exposes mid-stream drop', (
    WidgetTester tester,
  ) async {
    initJalaBinding();
    await pump(tester);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Drop mid-download'), findsOneWidget);
    // Two sliders now: connect-time drop and mid-stream drop.
    expect(find.byType(Slider), findsNWidgets(2));
  });

  testWidgets('applying a custom profile carries midStreamDropRate', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    await pump(tester);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    // The custom editor expands the list, so both targets need scrolling
    // into view before they can be driven.
    await tester.ensureVisible(find.byType(Slider).last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider).last, const Offset(200, 0));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Apply custom profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply custom profile'));
    await tester.pumpAndSettle();

    final JalaThrottleProfile? active = binding.throttleRegistry.activeProfile;
    expect(active, isNotNull);
    expect(
      active!.midStreamDropRate,
      greaterThan(0),
      reason: 'the slider must reach the profile, not just the UI',
    );
  });
}
