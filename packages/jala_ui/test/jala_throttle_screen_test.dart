import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);
  tearDown(JalaBinding.resetForTesting);

  testWidgets(
    'selecting a preset activates the registry and shows the inspector '
    'banner',
    (WidgetTester tester) async {
      initJalaBinding();

      await pumpJalaApp(tester, const JalaInspectorScreen());
      await pumpJalaSettle(tester);

      expect(find.textContaining('Throttling:'), findsNothing);

      await tester.tap(find.byIcon(Icons.speed));
      await pumpJalaSettle(tester);

      expect(find.text('Throttle'), findsOneWidget);
      await tester.tap(find.text('Slow 3G'));
      await pumpJalaSettle(tester);

      expect(
        JalaBinding.instance.throttleRegistry.activeProfile?.id,
        'slow3g',
      );

      await tester.pageBack();
      await pumpJalaSettle(tester);

      expect(
        find.text('Throttling: Slow 3G — tap to change'),
        findsOneWidget,
      );
    },
  );

  testWidgets('selecting Off clears the active profile', (
    WidgetTester tester,
  ) async {
    initJalaBinding();
    JalaBinding.instance.throttleRegistry.setActive(JalaThrottleProfile.flaky);

    await pumpJalaApp(tester, const JalaThrottleScreen());
    await pumpJalaSettle(tester);

    await tester.tap(find.text('Off'));
    await pumpJalaSettle(tester);

    expect(JalaBinding.instance.throttleRegistry.activeProfile, isNull);
  });

  testWidgets('custom editor applies entered values', (
    WidgetTester tester,
  ) async {
    initJalaBinding();

    await pumpJalaApp(tester, const JalaThrottleScreen());
    await pumpJalaSettle(tester);

    await tester.tap(find.text('Custom'));
    await pumpJalaSettle(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Latency (ms)'),
      '250',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Jitter ± (ms, optional)'),
      '50',
    );
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Download KB/s (optional, unlimited if blank)',
      ),
      '64',
    );

    // Host pattern sits after the custom editor; ListView builds children
    // lazily, so scroll until that trailing field is materialized.
    final Finder hostField = find.widgetWithText(
      TextField,
      'Host pattern (glob, optional)',
    );
    await tester.dragUntilVisible(
      hostField,
      find.byType(ListView),
      const Offset(0, -80),
    );
    await pumpJalaSettle(tester);
    await tester.enterText(hostField, '*.example.com');
    await pumpJalaSettle(tester);

    final Finder apply = find.text('Apply custom profile');
    await tester.dragUntilVisible(
      apply,
      find.byType(ListView),
      const Offset(0, 80),
    );
    await pumpJalaSettle(tester);
    await tester.tap(apply);
    await pumpJalaSettle(tester);

    final JalaThrottleProfile? active =
        JalaBinding.instance.throttleRegistry.activeProfile;
    expect(active, isNotNull);
    expect(active!.id, 'custom');
    expect(active.latencyMs, 250);
    expect(active.jitterMs, 50);
    expect(active.downloadBytesPerSec, 64 * 1024);
    expect(
      JalaBinding.instance.throttleRegistry.hostPattern,
      '*.example.com',
    );
  });
}
