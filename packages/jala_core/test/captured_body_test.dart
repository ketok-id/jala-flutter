import 'dart:convert';

import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

void main() {
  group('CapturedBody.capture', () {
    test('null -> kind none', () {
      final body = CapturedBody.capture(null);
      expect(body.kind, BodyKind.none);
      expect(body.text, isNull);
      expect(body.originalSize, isNull);
      expect(body.truncated, isFalse);
    });

    test('shared none constant has kind none', () {
      expect(CapturedBody.none.kind, BodyKind.none);
      expect(CapturedBody.none.truncated, isFalse);
    });

    test('plain string -> text', () {
      final body = CapturedBody.capture('hello world', contentType: 'text/plain');
      expect(body.kind, BodyKind.text);
      expect(body.text, 'hello world');
      expect(body.originalSize, utf8.encode('hello world').length);
      expect(body.truncated, isFalse);
      expect(body.contentType, 'text/plain');
    });

    test('string with json content type -> json', () {
      final body = CapturedBody.capture(
        '{"a": 1}',
        contentType: 'application/json; charset=utf-8',
      );
      expect(body.kind, BodyKind.json);
      expect(body.text, '{"a": 1}');
    });

    test('string that parses as JSON without content type -> json', () {
      final body = CapturedBody.capture('{"a": [1, 2, 3]}');
      expect(body.kind, BodyKind.json);
    });

    test('string that only looks JSON-ish stays text', () {
      final body = CapturedBody.capture('{not valid json');
      expect(body.kind, BodyKind.text);
    });

    test('Map -> jsonEncoded json', () {
      final body = CapturedBody.capture(<String, Object?>{'a': 1, 'b': 'x'});
      expect(body.kind, BodyKind.json);
      expect(jsonDecode(body.text!), {'a': 1, 'b': 'x'});
      expect(body.contentType, 'application/json');
    });

    test('List (non-bytes) -> jsonEncoded json', () {
      final body = CapturedBody.capture(<Object?>['a', 1, true]);
      expect(body.kind, BodyKind.json);
      expect(jsonDecode(body.text!), ['a', 1, true]);
    });

    test('bytes with texty content type are decoded as utf8', () {
      final bytes = utf8.encode('héllo ✓');
      final body = CapturedBody.capture(bytes, contentType: 'text/plain');
      expect(body.kind, BodyKind.text);
      expect(body.text, 'héllo ✓');
      expect(body.originalSize, bytes.length);
    });

    test('malformed utf8 bytes never throw and keep replacement chars', () {
      final bytes = <int>[0x68, 0x69, 0xC3, 0x28, 0xFF]; // invalid sequences
      final body = CapturedBody.capture(bytes, contentType: 'text/plain');
      expect(body.kind, BodyKind.text);
      expect(body.text, startsWith('hi'));
      expect(body.text, contains('�'));
      expect(body.originalSize, bytes.length);
    });

    test('binary bytes keep only metadata, never the payload', () {
      final bytes = List<int>.generate(1000, (i) => i % 256);
      final body = CapturedBody.capture(bytes, contentType: 'image/png');
      expect(body.kind, BodyKind.bytes);
      expect(body.text, isNull);
      expect(body.originalSize, 1000);
      expect(body.truncated, isFalse);
    });

    test('bytes without content type are treated as binary', () {
      final body = CapturedBody.capture(<int>[1, 2, 3]);
      expect(body.kind, BodyKind.bytes);
      expect(body.originalSize, 3);
    });

    test('oversize text is truncated to maxBytes with full originalSize', () {
      final text = 'a' * 100;
      final body = CapturedBody.capture(text, maxBytes: 10);
      expect(body.kind, BodyKind.truncated);
      expect(body.truncated, isTrue);
      expect(body.text, 'a' * 10);
      expect(body.originalSize, 100);
    });

    test('truncation across a multibyte character boundary never throws', () {
      // '€' is 3 bytes in utf8; cap of 4 bytes cuts the second euro sign.
      final body = CapturedBody.capture('€€€', maxBytes: 4);
      expect(body.kind, BodyKind.truncated);
      expect(body.text, startsWith('€'));
      expect(body.originalSize, 9);
    });

    test('oversize json is reported as truncated (not json)', () {
      final text = '{"k": "${'v' * 100}"}';
      final body = CapturedBody.capture(
        text,
        contentType: 'application/json',
        maxBytes: 16,
      );
      expect(body.kind, BodyKind.truncated);
      expect(body.truncated, isTrue);
    });

    test('stream -> metadata only, stream never consumed', () {
      var listened = false;
      final stream = Stream<List<int>>.multi((c) {
        listened = true;
        c.close();
      });
      final body = CapturedBody.capture(stream, contentType: 'video/mp4');
      expect(body.kind, BodyKind.stream);
      expect(body.text, isNull);
      expect(listened, isFalse);
    });

    test('arbitrary object falls back to toString without throwing', () {
      final body = CapturedBody.capture(DateTime.utc(2026));
      expect(body.kind, BodyKind.text);
      expect(body.text, contains('2026'));
    });

    test('defaultMaxBytes is 512 KB', () {
      expect(CapturedBody.defaultMaxBytes, 512 * 1024);
    });

    test('value equality', () {
      expect(
        CapturedBody.capture('x', contentType: 'text/plain'),
        CapturedBody.capture('x', contentType: 'text/plain'),
      );
    });
  });
}
