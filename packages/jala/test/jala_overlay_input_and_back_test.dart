// Regression tests for two bugs that shared one root cause: the inspector
// is a *sibling* of the host app, so it inherits nothing `WidgetsApp`
// provides — neither the text-editing shortcuts that turn a Backspace key
// event into a delete, nor a place in the back-dispatch chain.
//
// Both failed silently on Android while looking fine on iOS and in every
// existing test, so both are pinned here.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala/jala.dart';

void main() {
  setUpAll(() {
    // The filter TextField's cursor animation makes pumpAndSettle hang.
    EditableText.debugDeterministicCursor = true;
  });

  tearDown(() async {
    Jala.resetControllerForTesting();
    await JalaBinding.resetForTesting();
  });

  Widget host() => JalaOverlay(
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('host page 2')),
              ),
            ),
            child: const Text('push host route'),
          ),
        ),
      ),
    ),
  );

  group('Android backspace in inspector text fields', () {
    testWidgets('a Backspace key event deletes a character', (
      WidgetTester tester,
    ) async {
      Jala.initialize(config: JalaConfig(enabled: true));
      await tester.pumpWidget(host());
      Jala.open();
      await tester.pumpAndSettle();

      final Finder field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, 'status');
      await tester.pumpAndSettle();

      // enterText goes through the IME path (which always worked). The bug
      // was the *key event* path Gboard uses for delete on Android: with no
      // DefaultTextEditingShortcuts ancestor it mapped to no intent at all
      // and the text was left untouched.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(field).controller!.text,
        'statu',
        reason: 'Backspace key event must delete — the inspector lives '
            'outside WidgetsApp, so JalaOverlay has to install '
            'DefaultTextEditingShortcuts + default Actions itself.',
      );
    });

    testWidgets('Escape dismisses a sheet opened from the inspector', (
      WidgetTester tester,
    ) async {
      // Escape → DismissIntent lives in WidgetsApp.defaultShortcuts, which
      // is a *separate* widget from DefaultTextEditingShortcuts. Fixing
      // backspace alone left this broken: Escape, Tab traversal and
      // Enter/Space activation all come from that map, and all are
      // reachable wherever there's a keyboard — web demo, Chromebook,
      // Android tablet, desktop.
      // The help sheet is taller than the default 800x600 test surface.
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Jala.initialize(config: JalaConfig(enabled: true));
      await tester.pumpWidget(host());
      Jala.open();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.help_outline).first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        find.byType(BottomSheet),
        findsNothing,
        reason: 'Escape must dismiss — needs Shortcuts(defaultShortcuts)',
      );
    });
  });

  group('system back while the inspector is open', () {
    /// Fires the platform back the way Android does for a non-predictive
    /// gesture: `SystemNavigator.popRoute` over the navigation channel.
    Future<void> pressBack() async {
      await TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .handlePlatformMessage(
            'flutter/navigation',
            const JSONMethodCodec().encodeMethodCall(
              const MethodCall('popRoute'),
            ),
            (ByteData? _) {},
          );
    }

    testWidgets('back closes the inspector, not the host route', (
      WidgetTester tester,
    ) async {
      Jala.initialize(config: JalaConfig(enabled: true));
      await tester.pumpWidget(host());

      // Put the host on a second route so a leaked back is observable.
      await tester.tap(find.text('push host route'));
      await tester.pumpAndSettle();
      expect(find.text('host page 2'), findsOneWidget);

      Jala.open();
      await tester.pumpAndSettle();

      await pressBack();
      await tester.pumpAndSettle();

      expect(Jala.isOpen, isFalse, reason: 'back should close the inspector');
      expect(
        find.text('host page 2'),
        findsOneWidget,
        reason: 'the host route must be untouched — the old code registered '
            'its observer from the overlay State, which lands after the '
            "host's WidgetsApp, so the host popped instead",
      );
    });

    testWidgets('back pops the inspector stack before closing it', (
      WidgetTester tester,
    ) async {
      Jala.initialize(config: JalaConfig(enabled: true));
      await tester.pumpWidget(host());
      Jala.open();
      await tester.pumpAndSettle();

      // Push a second screen onto the inspector's own navigator.
      unawaited(
        Jala.inspectorNavigatorKey.currentState!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('inspector page 2')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('inspector page 2'), findsOneWidget);

      await pressBack();
      await tester.pumpAndSettle();
      expect(find.text('inspector page 2'), findsNothing);
      expect(Jala.isOpen, isTrue, reason: 'first back pops, does not close');

      await pressBack();
      await tester.pumpAndSettle();
      expect(Jala.isOpen, isFalse, reason: 'second back closes the inspector');
    });

    testWidgets('back is left to the host while the inspector is closed', (
      WidgetTester tester,
    ) async {
      Jala.initialize(config: JalaConfig(enabled: true));
      await tester.pumpWidget(host());
      await tester.tap(find.text('push host route'));
      await tester.pumpAndSettle();

      await pressBack();
      await tester.pumpAndSettle();

      expect(
        find.text('host page 2'),
        findsNothing,
        reason: 'Jala must decline back when closed, so the host pops',
      );
    });
  });

  group('Android predictive back gesture (API 33+)', () {
    /// Predictive back never reaches didPopRoute — it arrives on its own
    /// channel and is dispatched through handleStartBackGesture /
    /// handleCommitBackGesture instead, so it needs its own coverage.
    Future<void> sendGesture(String method, [Object? args]) async {
      await TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .handlePlatformMessage(
            'flutter/backgesture',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, args),
            ),
            (ByteData? _) {},
          );
    }

    Future<void> swipeBack(WidgetTester tester) async {
      await sendGesture('startBackGesture', <String, dynamic>{
        'x': 0.0,
        'y': 0.0,
        'progress': 0.0,
        'swipeEdge': 0,
        'isButtonEvent': false,
      });
      await tester.pumpAndSettle();
      await sendGesture('commitBackGesture');
      await tester.pumpAndSettle();
    }

    /// A host that opts into Material's predictive page transitions — the
    /// case where the host's own route registers a competing gesture
    /// observer, which is what makes this worth pinning.
    Widget predictiveHost() => JalaOverlay(
      child: MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: <TargetPlatform, PageTransitionsBuilder>{
              TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
            },
          ),
        ),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('host page 2')),
                ),
              ),
              child: const Text('push host route'),
            ),
          ),
        ),
      ),
    );

    testWidgets('closes the inspector and leaves the host route alone', (
      WidgetTester tester,
    ) async {
      // Must be cleared before the test body returns — flutter_test asserts
      // no foundation debug var outlives the test, and addTearDown runs
      // after that check.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      Jala.initialize(config: JalaConfig(enabled: true));
      await tester.pumpWidget(predictiveHost());
      await tester.tap(find.text('push host route'));
      await tester.pumpAndSettle();

      // Control: with the inspector closed, the host's own predictive
      // detector must handle the gesture. Without this the assertions below
      // would pass even if the gesture were never dispatched at all.
      await swipeBack(tester);
      final bool hostHandledControl =
          find.text('host page 2').evaluate().isEmpty;

      await tester.tap(find.text('push host route'));
      await tester.pumpAndSettle();
      Jala.open();
      await tester.pumpAndSettle();

      await swipeBack(tester);

      final bool closed = !Jala.isOpen;
      final bool hostIntact = find.text('host page 2').evaluate().isNotEmpty;
      debugDefaultTargetPlatformOverride = null;

      expect(
        hostHandledControl,
        isTrue,
        reason: 'control — the host handles predictive back when Jala is '
            'closed, proving the gesture really is being dispatched',
      );
      expect(closed, isTrue, reason: 'the gesture closes the inspector');
      expect(
        hostIntact,
        isTrue,
        reason: 'and must not also pop the host route behind it',
      );
    });
  });
}
