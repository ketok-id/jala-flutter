import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala/jala.dart';

void main() {
  tearDown(() async {
    Jala.resetControllerForTesting();
    await JalaBinding.resetForTesting();
  });

  test('initialize defaults enabled to kDebugMode', () {
    Jala.initialize();
    expect(Jala.isInitialized, isTrue);
    expect(Jala.isEnabled, kDebugMode);
    expect(Jala.store, isNotNull);
    expect(Jala.bus, isNotNull);
  });

  test('initialize is idempotent', () {
    Jala.initialize(config: JalaConfig(enabled: true, maxEntries: 10));
    Jala.initialize(config: JalaConfig(enabled: false, maxEntries: 999));
    expect(Jala.isEnabled, isTrue);
    expect(Jala.store.maxEntries, 10);
  });

  test('open/close no-op when disabled', () {
    Jala.initialize(config: JalaConfig(enabled: false));
    Jala.open();
    expect(Jala.isOpen, isFalse);
  });

  test('open/close toggles controller when enabled', () {
    Jala.initialize(config: JalaConfig(enabled: true));
    expect(Jala.isOpen, isFalse);
    Jala.open();
    expect(Jala.isOpen, isTrue);
    Jala.close();
    expect(Jala.isOpen, isFalse);
  });

  testWidgets('JalaOverlay returns child only when disabled', (
    WidgetTester tester,
  ) async {
    Jala.initialize(config: JalaConfig(enabled: false));
    await tester.pumpWidget(
      const MaterialApp(
        home: JalaOverlay(child: Text('host-app')),
      ),
    );
    expect(find.text('host-app'), findsOneWidget);
    expect(find.text('J'), findsNothing);
  });

  testWidgets('JalaOverlay shows bubble and opens inspector when enabled', (
    WidgetTester tester,
  ) async {
    EditableText.debugDeterministicCursor = true;
    Jala.initialize(config: JalaConfig(enabled: true));
    await tester.pumpWidget(
      const MaterialApp(
        home: JalaOverlay(child: Scaffold(body: Text('host-app'))),
      ),
    );
    await tester.pump();

    expect(find.text('host-app'), findsOneWidget);
    expect(find.text('J'), findsOneWidget);

    await tester.tap(find.text('J'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(Jala.isOpen, isTrue);
    expect(find.text('Jala'), findsOneWidget);
    expect(find.text('No network calls captured yet.'), findsOneWidget);
  });

  testWidgets(
    'inspector opens when MaterialApp is INSIDE JalaOverlay '
    '(documented runApp(JalaOverlay(child: MyApp())) usage — regression '
    'for missing MaterialLocalizations)',
    (WidgetTester tester) async {
      Jala.initialize(config: JalaConfig(enabled: true));
      await tester.pumpWidget(
        const JalaOverlay(
          child: MaterialApp(
            home: Scaffold(body: Text('host-app')),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('J'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(Jala.isOpen, isTrue);
      expect(find.text('Jala'), findsOneWidget);
    },
  );

  testWidgets(
    'system back closes the inspector instead of reaching the host app '
    '(regression: Android back exited the app while inspector was open)',
    (WidgetTester tester) async {
      Jala.initialize(config: JalaConfig(enabled: true));
      await tester.pumpWidget(
        const JalaOverlay(
          child: MaterialApp(home: Scaffold(body: Text('host-app'))),
        ),
      );
      Jala.open();
      await tester.pumpAndSettle();
      expect(Jala.isOpen, isTrue);

      final bool handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue, reason: 'back must not fall through to host');
      expect(Jala.isOpen, isFalse);
      expect(find.text('host-app'), findsOneWidget);
    },
  );

  testWidgets('inspector root shows a close button that closes the overlay', (
    WidgetTester tester,
  ) async {
    Jala.initialize(config: JalaConfig(enabled: true));
    await tester.pumpWidget(
      const JalaOverlay(
        child: MaterialApp(home: Scaffold(body: Text('host-app'))),
      ),
    );
    Jala.open();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close inspector'));
    await tester.pumpAndSettle();

    expect(Jala.isOpen, isFalse);
  });
}
