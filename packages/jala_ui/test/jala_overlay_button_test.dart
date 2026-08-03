import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

void main() {
  tearDown(() async {
    JalaOverlayButton.resetPositionForTesting();
    await JalaBinding.resetForTesting();
  });

  /// Mounts the bubble the way `JalaOverlay` does — inside a `Stack` whose
  /// presence is toggled, so unmounting it models opening the inspector.
  Future<void> pumpBubble(WidgetTester tester, {required bool visible}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: <Widget>[
            if (visible) JalaOverlayButton(onTap: () {}),
          ],
        ),
      ),
    );
  }

  Offset bubbleTopLeft(WidgetTester tester) =>
      tester.getTopLeft(find.byType(JalaOverlayButton));

  testWidgets('renders the J glyph and invokes onTap', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: <Widget>[JalaOverlayButton(onTap: () => tapped = true)],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('J'), findsOneWidget);

    await tester.tap(find.text('J'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('keeps its dragged position across an unmount/remount', (
    WidgetTester tester,
  ) async {
    // Regression: `JalaOverlay` removes the bubble from the tree while the
    // inspector is open, which disposed the State holding its position —
    // so closing the inspector snapped the bubble back to the default
    // right-edge spot, losing wherever the user had dragged it.
    await pumpBubble(tester, visible: true);
    await tester.pump();
    final Offset before = bubbleTopLeft(tester);

    await tester.drag(find.text('J'), const Offset(0, -200));
    await tester.pumpAndSettle();
    final Offset dragged = bubbleTopLeft(tester);
    expect(dragged.dy, lessThan(before.dy), reason: 'drag should move it up');

    // Inspector opens (bubble unmounted) …
    await pumpBubble(tester, visible: false);
    await tester.pump();
    expect(find.byType(JalaOverlayButton), findsNothing);

    // … and closes again.
    await pumpBubble(tester, visible: true);
    await tester.pump();
    expect(bubbleTopLeft(tester), dragged);
  });

  testWidgets('a retained position is re-clamped into smaller bounds', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1200);

    await pumpBubble(tester, visible: true);
    await tester.pump();
    await tester.drag(find.text('J'), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(bubbleTopLeft(tester).dy, greaterThan(900));

    // Rotate/resize to a much shorter viewport while the bubble is away.
    await pumpBubble(tester, visible: false);
    tester.view.physicalSize = const Size(800, 400);
    await pumpBubble(tester, visible: true);
    await tester.pump();

    // Still on screen rather than stranded below the fold.
    expect(bubbleTopLeft(tester).dy, lessThanOrEqualTo(400 - 56));
  });

  testWidgets('resetPositionForTesting returns it to the default', (
    WidgetTester tester,
  ) async {
    await pumpBubble(tester, visible: true);
    await tester.pump();
    final Offset original = bubbleTopLeft(tester);

    await tester.drag(find.text('J'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(bubbleTopLeft(tester), isNot(original));

    JalaOverlayButton.resetPositionForTesting();
    await pumpBubble(tester, visible: false);
    await pumpBubble(tester, visible: true);
    await tester.pump();
    expect(bubbleTopLeft(tester), original);
  });
}
