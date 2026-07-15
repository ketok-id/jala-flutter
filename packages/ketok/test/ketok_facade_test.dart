import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ketok/ketok.dart';

void main() {
  tearDown(() async {
    Ketok.resetControllerForTesting();
    await KetokBinding.resetForTesting();
  });

  test('initialize defaults enabled to kDebugMode', () {
    Ketok.initialize();
    expect(Ketok.isInitialized, isTrue);
    expect(Ketok.isEnabled, kDebugMode);
    expect(Ketok.store, isNotNull);
    expect(Ketok.bus, isNotNull);
  });

  test('initialize is idempotent', () {
    Ketok.initialize(config: KetokConfig(enabled: true, maxEntries: 10));
    Ketok.initialize(config: KetokConfig(enabled: false, maxEntries: 999));
    expect(Ketok.isEnabled, isTrue);
    expect(Ketok.store.maxEntries, 10);
  });

  test('open/close no-op when disabled', () {
    Ketok.initialize(config: KetokConfig(enabled: false));
    Ketok.open();
    expect(Ketok.isOpen, isFalse);
  });

  test('open/close toggles controller when enabled', () {
    Ketok.initialize(config: KetokConfig(enabled: true));
    expect(Ketok.isOpen, isFalse);
    Ketok.open();
    expect(Ketok.isOpen, isTrue);
    Ketok.close();
    expect(Ketok.isOpen, isFalse);
  });

  testWidgets('KetokOverlay returns child only when disabled', (
    WidgetTester tester,
  ) async {
    Ketok.initialize(config: KetokConfig(enabled: false));
    await tester.pumpWidget(
      const MaterialApp(
        home: KetokOverlay(child: Text('host-app')),
      ),
    );
    expect(find.text('host-app'), findsOneWidget);
    expect(find.text('K'), findsNothing);
  });

  testWidgets('KetokOverlay shows bubble and opens inspector when enabled', (
    WidgetTester tester,
  ) async {
    EditableText.debugDeterministicCursor = true;
    Ketok.initialize(config: KetokConfig(enabled: true));
    await tester.pumpWidget(
      const MaterialApp(
        home: KetokOverlay(child: Scaffold(body: Text('host-app'))),
      ),
    );
    await tester.pump();

    expect(find.text('host-app'), findsOneWidget);
    expect(find.text('K'), findsOneWidget);

    await tester.tap(find.text('K'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(Ketok.isOpen, isTrue);
    expect(find.text('Ketok'), findsOneWidget);
    expect(find.text('No network calls captured yet.'), findsOneWidget);
  });

  testWidgets(
    'inspector opens when MaterialApp is INSIDE KetokOverlay '
    '(documented runApp(KetokOverlay(child: MyApp())) usage — regression '
    'for missing MaterialLocalizations)',
    (WidgetTester tester) async {
      Ketok.initialize(config: KetokConfig(enabled: true));
      await tester.pumpWidget(
        const KetokOverlay(
          child: MaterialApp(
            home: Scaffold(body: Text('host-app')),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('K'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(Ketok.isOpen, isTrue);
      expect(find.text('Ketok'), findsOneWidget);
    },
  );

  testWidgets(
    'system back closes the inspector instead of reaching the host app '
    '(regression: Android back exited the app while inspector was open)',
    (WidgetTester tester) async {
      Ketok.initialize(config: KetokConfig(enabled: true));
      await tester.pumpWidget(
        const KetokOverlay(
          child: MaterialApp(home: Scaffold(body: Text('host-app'))),
        ),
      );
      Ketok.open();
      await tester.pumpAndSettle();
      expect(Ketok.isOpen, isTrue);

      final bool handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue, reason: 'back must not fall through to host');
      expect(Ketok.isOpen, isFalse);
      expect(find.text('host-app'), findsOneWidget);
    },
  );

  testWidgets('inspector root shows a close button that closes the overlay', (
    WidgetTester tester,
  ) async {
    Ketok.initialize(config: KetokConfig(enabled: true));
    await tester.pumpWidget(
      const KetokOverlay(
        child: MaterialApp(home: Scaffold(body: Text('host-app'))),
      ),
    );
    Ketok.open();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close inspector'));
    await tester.pumpAndSettle();

    expect(Ketok.isOpen, isFalse);
  });
}
