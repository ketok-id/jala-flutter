import 'dart:convert';
import 'dart:typed_data';

import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 7, 15, 12);

  group('WsFrame.capture', () {
    test('text data produces a non-binary frame with a preview', () {
      final frame = WsFrame.capture(
        timestamp: timestamp,
        direction: WsDirection.sent,
        data: 'hello world',
        redactor: JalaRedactor(),
      );

      expect(frame.isBinary, isFalse);
      expect(frame.preview, 'hello world');
      expect(frame.size, utf8.encode('hello world').length);
      expect(frame.direction, WsDirection.sent);
      expect(frame.timestamp, timestamp);
    });

    test('binary data (List<int>) is metadata-only', () {
      final bytes = Uint8List.fromList(List<int>.filled(128, 7));
      final frame = WsFrame.capture(
        timestamp: timestamp,
        direction: WsDirection.received,
        data: bytes,
        redactor: JalaRedactor(),
      );

      expect(frame.isBinary, isTrue);
      expect(frame.preview, isNull);
      expect(frame.size, 128);
    });

    test('text preview is capped at 4 KB', () {
      final long = 'x' * (WsFrame.maxPreviewBytes + 500);
      final frame = WsFrame.capture(
        timestamp: timestamp,
        direction: WsDirection.sent,
        data: long,
        redactor: JalaRedactor(),
      );

      expect(frame.isBinary, isFalse);
      expect(utf8.encode(frame.preview!).length, WsFrame.maxPreviewBytes);
      expect(
        frame.size,
        utf8.encode(long).length,
        reason: 'reported size is the original, uncapped size',
      );
    });

    test('text under the cap is not truncated', () {
      final text = 'x' * (WsFrame.maxPreviewBytes - 1);
      final frame = WsFrame.capture(
        timestamp: timestamp,
        direction: WsDirection.sent,
        data: text,
        redactor: JalaRedactor(),
      );
      expect(frame.preview, text);
    });

    test('redaction is applied to text previews via the body patterns', () {
      final redactor = JalaRedactor(
        redactedBodyPatterns: [RegExp(r'"token"\s*:\s*"[^"]*"')],
      );
      final frame = WsFrame.capture(
        timestamp: timestamp,
        direction: WsDirection.sent,
        data: '{"token": "super-secret", "ok": true}',
        redactor: redactor,
      );

      expect(frame.preview, contains(JalaRedactor.mask));
      expect(frame.preview, isNot(contains('super-secret')));
    });

    test('binary frames are never redacted or previewed', () {
      final redactor = JalaRedactor(
        redactedBodyPatterns: [RegExp('.*', dotAll: true)],
      );
      final frame = WsFrame.capture(
        timestamp: timestamp,
        direction: WsDirection.received,
        data: Uint8List.fromList([1, 2, 3]),
        redactor: redactor,
      );
      expect(frame.preview, isNull);
      expect(frame.isBinary, isTrue);
    });

    test('non-String/List<int> data falls back to toString()', () {
      final frame = WsFrame.capture(
        timestamp: timestamp,
        direction: WsDirection.sent,
        data: 42,
        redactor: JalaRedactor(),
      );
      expect(frame.isBinary, isFalse);
      expect(frame.preview, '42');
    });
  });
}
