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

  testWidgets('search field filters to matching nodes and highlights them', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JalaJsonTree(
            data: <String, dynamic>{
              'alpha': 'keep me',
              'beta': 'drop me',
            },
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
}
