import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

void main() {
  setUpAll(() {
    EditableText.debugDeterministicCursor = true;
  });

  NetworkCallEntry entry({
    String method = 'GET',
    String url = 'https://api.example.com/x',
    int? statusCode = 200,
    Map<String, String> responseHeaders = const <String, String>{},
    CapturedBody? responseBody,
  }) {
    return NetworkCallEntry(
      id: 'id-$url-$statusCode-${responseHeaders.hashCode}',
      startTime: DateTime.utc(2026, 7, 24),
      method: method,
      uri: Uri.parse(url),
      requestHeaders: const <String, String>{},
      requestBody: CapturedBody.none,
      responseHeaders: responseHeaders,
      responseBody: responseBody ?? CapturedBody.none,
      statusCode: statusCode,
      status: JalaCallStatus.success,
      client: 'test',
    );
  }

  group('JalaJsonDiffView', () {
    testWidgets('marks added, removed and changed leaves', (
      WidgetTester tester,
    ) async {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <String, Object?>{'a': 1, 'keep': true},
        <String, Object?>{'a': 2, 'added': 9},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: JalaJsonDiffView(root: root)),
          ),
        ),
      );
      await tester.pump();

      // Changed leaf shows before → after.
      expect(find.textContaining('1  →  2'), findsOneWidget);
      // Added and removed keys each render a row.
      expect(find.textContaining('added'), findsOneWidget);
      expect(find.textContaining('keep'), findsOneWidget);
    });

    testWidgets('identical values render an "Identical" note', (
      WidgetTester tester,
    ) async {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <String, Object?>{'a': 1},
        <String, Object?>{'a': 1},
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: JalaJsonDiffView(root: root))),
      );
      await tester.pump();

      expect(find.text('Identical'), findsOneWidget);
    });
  });

  group('JalaCallDiffScreen', () {
    testWidgets('shows status change, header diffs and a body diff', (
      WidgetTester tester,
    ) async {
      final NetworkCallEntry a = entry(
        statusCode: 200,
        responseHeaders: const <String, String>{'x-a': '1', 'shared': 's'},
        responseBody: CapturedBody.capture(
          <String, Object?>{'n': 1},
          contentType: 'application/json',
        ),
      );
      final NetworkCallEntry b = entry(
        statusCode: 404,
        responseHeaders: const <String, String>{'x-b': '2', 'shared': 's'},
        responseBody: CapturedBody.capture(
          <String, Object?>{'n': 2},
          contentType: 'application/json',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: JalaCallDiffScreen(a: a, b: b)),
      );
      await tester.pumpAndSettle();

      // Status line shows the change.
      expect(find.textContaining('200  →  404'), findsOneWidget);
      // A removed and an added response header.
      expect(find.textContaining('x-a'), findsOneWidget);
      expect(find.textContaining('x-b'), findsOneWidget);
      // Response body is JSON on both sides → one structural diff view.
      expect(find.byType(JalaJsonDiffView), findsOneWidget);
    });
  });
}
