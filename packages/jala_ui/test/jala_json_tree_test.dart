import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_ui/jala_ui.dart';

void main() {
  setUpAll(() {
    EditableText.debugDeterministicCursor = true;
  });

  testWidgets('root starts expanded, nested containers start collapsed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JalaJsonTree(
            data: <String, dynamic>{
              'id': 1,
              'nested': <String, dynamic>{'flag': true},
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('id: 1'), findsOneWidget);
    expect(find.text('nested'), findsOneWidget);
    expect(find.textContaining('flag'), findsNothing);
  });

  testWidgets('tapping a container node expands its children', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JalaJsonTree(
            data: <String, dynamic>{
              'nested': <String, dynamic>{'flag': true},
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('nested'));
    await tester.pump();

    expect(find.textContaining('flag: true'), findsOneWidget);
  });

  testWidgets('Expand all opens every nested container', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JalaJsonTree(
            data: <String, dynamic>{
              'id': 1,
              'nested': <String, dynamic>{'flag': true},
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('flag'), findsNothing);

    await tester.tap(find.byTooltip('Expand all'));
    await tester.pump();

    expect(find.textContaining('flag: true'), findsOneWidget);
  });

  testWidgets('Collapse all returns to top-level keys only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JalaJsonTree(
            data: <String, dynamic>{
              'id': 1,
              'nested': <String, dynamic>{'flag': true},
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Expand all'));
    await tester.pump();
    expect(find.textContaining('flag: true'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse all'));
    await tester.pump();

    // Nested value hidden again, but the top-level key stays visible.
    expect(find.textContaining('flag'), findsNothing);
    expect(find.text('nested'), findsOneWidget);
  });

  testWidgets('search field filters to matching nodes and highlights them', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JalaJsonTree(
            data: <String, dynamic>{'alpha': 'keep me', 'beta': 'drop me'},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'keep');
    await tester.pump();

    expect(find.textContaining('alpha'), findsOneWidget);
    expect(find.textContaining('beta'), findsNothing);
  });

  testWidgets('search shows a match count and a clear button that resets it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JalaJsonTree(
            data: <String, dynamic>{'alpha': 'keep me', 'beta': 'drop me'},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'keep');
    await tester.pump();

    // Only alpha's value matches → a single, singular-labelled match.
    expect(find.text('1 match'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    // Search reset: both entries visible again, count gone.
    expect(find.text('1 match'), findsNothing);
    expect(find.textContaining('beta'), findsOneWidget);
  });

  testWidgets('a no-hit query reports "No matches"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JalaJsonTree(data: <String, dynamic>{'alpha': 'value'}),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();

    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('leaf values are colored by JSON type', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JalaJsonTree(
            data: <String, dynamic>{
              'str': 'hello',
              'num': 42,
              'nul': null,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    Color colorOf(String keyLabel) {
      final Text text = tester.widget<Text>(
        find.textContaining('$keyLabel: '),
      );
      final TextSpan root = text.textSpan! as TextSpan;
      // children[0] is the bold key span; children[1] is the value span.
      final TextSpan valueSpan = root.children![1] as TextSpan;
      return valueSpan.style!.color!;
    }

    // Each type resolves to its own color — enough to prove they differ.
    expect(colorOf('str') == colorOf('num'), isFalse);
    expect(colorOf('str') == colorOf('nul'), isFalse);
    expect(colorOf('num') == colorOf('nul'), isFalse);

    // null also renders italic.
    final Text nullText = tester.widget<Text>(find.textContaining('nul: '));
    final TextSpan nullValue =
        (nullText.textSpan! as TextSpan).children![1] as TextSpan;
    expect(nullValue.style!.fontStyle, FontStyle.italic);
  });

  testWidgets('flattened list drives a ListView (virtualization path)', (
    WidgetTester tester,
  ) async {
    // Large-enough top-level map that a recursive Column used to build
    // eagerly; the tree should expose a ListView for lazy rows.
    final Map<String, dynamic> data = <String, dynamic>{
      for (int i = 0; i < 80; i++) 'k$i': i,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JalaJsonTree(data: data)),
      ),
    );
    await tester.pump();

    expect(find.byType(ListView), findsOneWidget);
    // Root + first leaves are visible; far keys only after scroll.
    expect(find.textContaining('k0: 0'), findsOneWidget);
    expect(find.textContaining('k79: 79'), findsNothing);

    // Scroll the tree's ListView (not the TextField's internal Scrollable).
    final Finder treeList = find.descendant(
      of: find.byType(JalaJsonTree),
      matching: find.byType(ListView),
    );
    await tester.drag(treeList, const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.textContaining('k79: 79'), findsOneWidget);
  });

  testWidgets('nested in a parent scroll view still expands/search works', (
    WidgetTester tester,
  ) async {
    // Call-detail / body pane nests the tree in a ListView (unbounded
    // height) — shrink-wrap path must keep expand + search parity.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const <Widget>[
              JalaJsonTree(
                data: <String, dynamic>{
                  'id': 1,
                  'nested': <String, dynamic>{'flag': true},
                  'alpha': 'keep me',
                  'beta': 'drop me',
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('flag'), findsNothing);
    await tester.tap(find.byTooltip('Expand all'));
    await tester.pump();
    expect(find.textContaining('flag: true'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'keep');
    await tester.pump();
    expect(find.text('1 match'), findsOneWidget);
    expect(find.textContaining('beta'), findsNothing);
  });
}
