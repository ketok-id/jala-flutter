import 'dart:convert';

import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

void main() {
  group('CapturedBodyMultipart.capture', () {
    test('captures parts under the @multipart JSON convention', () {
      final CapturedBody body = CapturedBodyMultipart.capture(
        const <JalaMultipartPart>[
          JalaMultipartPart(name: 'field', size: 4),
          JalaMultipartPart(
            name: 'file',
            filename: 'hello.txt',
            contentType: 'text/plain',
            size: 24,
          ),
        ],
      );

      expect(body.kind, BodyKind.json);
      final Map<String, dynamic> decoded =
          jsonDecode(body.text!) as Map<String, dynamic>;
      final List<dynamic> parts = decoded[multipartBodyKey] as List<dynamic>;
      expect(parts, hasLength(2));
      expect(parts[0], <String, Object?>{'name': 'field', 'size': 4});
      expect(parts[1], <String, Object?>{
        'name': 'file',
        'filename': 'hello.txt',
        'contentType': 'text/plain',
        'size': 24,
      });
    });

    test('round-trips through partsOf', () {
      const List<JalaMultipartPart> original = <JalaMultipartPart>[
        JalaMultipartPart(name: 'a', size: 1),
        JalaMultipartPart(
          name: 'b',
          filename: 'b.png',
          contentType: 'image/png',
          size: 2,
        ),
      ];
      final CapturedBody body = CapturedBodyMultipart.capture(original);
      expect(CapturedBodyMultipart.partsOf(body), original);
    });
  });

  group('CapturedBodyMultipart.partsOf', () {
    test('returns null for a plain JSON body', () {
      final CapturedBody body = CapturedBody.capture(
        <String, dynamic>{'hello': 'world'},
      );
      expect(CapturedBodyMultipart.partsOf(body), isNull);
    });

    test('returns null for a non-JSON text body', () {
      final CapturedBody body = CapturedBody.capture(
        'plain text',
        contentType: 'text/plain',
      );
      expect(CapturedBodyMultipart.partsOf(body), isNull);
    });

    test('returns null for a truncated body (incomplete JSON)', () {
      final CapturedBody body = CapturedBodyMultipart.capture(
        const <JalaMultipartPart>[
          JalaMultipartPart(name: 'field', size: 4),
          JalaMultipartPart(
            name: 'file',
            filename: 'hello.txt',
            contentType: 'text/plain',
            size: 24,
          ),
        ],
        maxBytes: 5,
      );
      expect(body.kind, BodyKind.truncated);
      expect(CapturedBodyMultipart.partsOf(body), isNull);
    });

    test('returns null for none/bytes/image bodies', () {
      expect(CapturedBodyMultipart.partsOf(CapturedBody.none), isNull);
      final CapturedBody bytesBody = CapturedBody.capture(
        <int>[1, 2, 3],
        contentType: 'application/octet-stream',
      );
      expect(CapturedBodyMultipart.partsOf(bytesBody), isNull);
    });

    test('an empty parts list round-trips as an empty list', () {
      final CapturedBody body = CapturedBodyMultipart.capture(
        const <JalaMultipartPart>[],
      );
      expect(CapturedBodyMultipart.partsOf(body), isEmpty);
    });
  });

  group('JalaMultipartPart', () {
    test('fromJson rejects malformed entries', () {
      expect(JalaMultipartPart.fromJson('not a map'), isNull);
      expect(JalaMultipartPart.fromJson(<String, Object?>{'size': 1}), isNull);
      expect(
        JalaMultipartPart.fromJson(<String, Object?>{'name': 'a'}),
        isNull,
      );
    });

    test('equality compares all fields', () {
      const JalaMultipartPart a = JalaMultipartPart(name: 'x', size: 1);
      const JalaMultipartPart b = JalaMultipartPart(name: 'x', size: 1);
      const JalaMultipartPart c = JalaMultipartPart(name: 'y', size: 1);
      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
