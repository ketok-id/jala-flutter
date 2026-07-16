import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

/// A valid, minimal 1x1 transparent PNG (68 bytes).
final Uint8List onePixelPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+A8AAQUBAScY'
    '42YAAAAASUVORK5CYII=',
  ),
);

void main() {
  setUpAll(() {
    EditableText.debugDeterministicCursor = true;
  });

  Future<void> pumpBody(WidgetTester tester, CapturedBody body) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JalaBodyView(body: body)),
      ),
    );
  }

  group('JalaBodyView / BodyKind.image', () {
    testWidgets('a valid PNG fixture renders an Image widget', (
      WidgetTester tester,
    ) async {
      final body = CapturedBody.image(
        onePixelPng,
        originalSize: onePixelPng.length,
        truncated: false,
        contentType: 'image/png',
      );
      await pumpBody(tester, body);
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      final Image image = tester.widget(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect((image.image as MemoryImage).bytes, onePixelPng);
      // Size/mime caption.
      expect(find.textContaining('image/png'), findsOneWidget);
    });

    testWidgets('corrupted bytes fall back to the binary info card', (
      WidgetTester tester,
    ) async {
      final corrupted = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      final body = CapturedBody.image(
        corrupted,
        originalSize: corrupted.length,
        truncated: false,
        contentType: 'image/png',
      );
      await pumpBody(tester, body);
      // Let Image.memory's async decode fail and errorBuilder rebuild.
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.broken_image), findsOneWidget);
      expect(find.textContaining('Binary —'), findsOneWidget);
      expect(find.textContaining('metadata only'), findsOneWidget);
    });

    testWidgets('tapping the preview pushes a full-screen viewer', (
      WidgetTester tester,
    ) async {
      final body = CapturedBody.image(
        onePixelPng,
        originalSize: onePixelPng.length,
        truncated: false,
        contentType: 'image/png',
      );
      await pumpBody(tester, body);
      await tester.pump();

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      // Two Image widgets now: the (unmounted-but-still-in-tree during
      // transition) inline preview and the full-screen one — at minimum
      // the full-screen InteractiveViewer must contain one.
      expect(
        find.descendant(
          of: find.byType(InteractiveViewer),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    });
  });

  group('JalaBodyView / multipart (@multipart convention)', () {
    testWidgets('renders a parts table instead of the raw JSON tree', (
      WidgetTester tester,
    ) async {
      final body = CapturedBodyMultipart.capture(const <JalaMultipartPart>[
        JalaMultipartPart(name: 'field', size: 4),
        JalaMultipartPart(
          name: 'file',
          filename: 'hello.txt',
          contentType: 'text/plain',
          size: 24,
        ),
      ]);
      await pumpBody(tester, body);
      await tester.pump();

      // Table rendering, not the JSON tree (which would show `@multipart`
      // as a key).
      expect(find.byType(JalaJsonTree), findsNothing);
      expect(find.text('field'), findsOneWidget);
      expect(find.text('file'), findsOneWidget);
      expect(find.text('hello.txt'), findsOneWidget);
      expect(find.text('text/plain'), findsOneWidget);
      expect(find.text('24 B'), findsOneWidget);
    });

    testWidgets('an empty parts list shows a friendly message', (
      WidgetTester tester,
    ) async {
      final body = CapturedBodyMultipart.capture(const <JalaMultipartPart>[]);
      await pumpBody(tester, body);
      await tester.pump();

      expect(find.text('Multipart body with no parts'), findsOneWidget);
    });
  });
}
