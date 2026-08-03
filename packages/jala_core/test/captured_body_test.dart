import 'dart:convert';
import 'dart:typed_data';

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
      final body = CapturedBody.capture(
        'hello world',
        contentType: 'text/plain',
      );
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

  group('CapturedBody.image', () {
    test('wraps bytes as BodyKind.image', () {
      final bytes = Uint8List.fromList(List<int>.generate(10, (i) => i));
      final body = CapturedBody.image(
        bytes,
        originalSize: 10,
        truncated: false,
        contentType: 'image/png',
      );
      expect(body.kind, BodyKind.image);
      expect(body.bytes, same(bytes));
      expect(body.originalSize, 10);
      expect(body.truncated, isFalse);
      expect(body.contentType, 'image/png');
      expect(body.text, isNull);
    });
  });

  group('CapturedBody.captureBytes', () {
    test('image within cap is kept as BodyKind.image', () {
      final bytes = List<int>.generate(67, (i) => i % 256);
      final body = CapturedBody.captureBytes(
        bytes,
        contentType: 'image/png',
        maxBytes: 1024,
        captureImages: true,
      );
      expect(body.kind, BodyKind.image);
      expect(body.bytes, isNotNull);
      expect(body.bytes, bytes);
      expect(body.originalSize, 67);
      expect(body.contentType, 'image/png');
    });

    test('image over the cap falls back to metadata-only bytes', () {
      final bytes = List<int>.generate(200, (i) => i % 256);
      final body = CapturedBody.captureBytes(
        bytes,
        contentType: 'image/png',
        maxBytes: 100,
        captureImages: true,
      );
      expect(body.kind, BodyKind.bytes);
      expect(body.bytes, isNull);
      expect(body.originalSize, 200);
    });

    test('captureImages: false keeps images metadata-only', () {
      final bytes = List<int>.generate(20, (i) => i);
      final body = CapturedBody.captureBytes(
        bytes,
        contentType: 'image/jpeg',
        maxBytes: 1024,
        captureImages: false,
      );
      expect(body.kind, BodyKind.bytes);
      expect(body.bytes, isNull);
      expect(body.originalSize, 20);
    });

    test('non-image bytes are unaffected (still metadata-only)', () {
      final bytes = List<int>.generate(20, (i) => i);
      final body = CapturedBody.captureBytes(
        bytes,
        contentType: 'application/octet-stream',
        maxBytes: 1024,
        captureImages: true,
      );
      expect(body.kind, BodyKind.bytes);
      expect(body.bytes, isNull);
      expect(body.originalSize, 20);
    });

    test('null content type never becomes an image capture', () {
      final bytes = List<int>.generate(10, (i) => i);
      final body = CapturedBody.captureBytes(
        bytes,
        maxBytes: 1024,
        captureImages: true,
      );
      expect(body.kind, BodyKind.bytes);
      expect(body.bytes, isNull);
    });

    test('bytes at exactly maxBytes are still captured as image', () {
      final bytes = List<int>.generate(50, (i) => i);
      final body = CapturedBody.captureBytes(
        bytes,
        contentType: 'image/gif',
        maxBytes: 50,
        captureImages: true,
      );
      expect(body.kind, BodyKind.image);
    });
  });

  group('CapturedBody toJson/fromJson', () {
    test('text round-trips', () {
      final body = CapturedBody.capture('hello', contentType: 'text/plain');
      final decoded = CapturedBody.fromJson(body.toJson());
      expect(decoded, body);
      expect(decoded.text, 'hello');
    });

    test('json round-trips', () {
      final body = CapturedBody.capture('{"a":1}');
      final decoded = CapturedBody.fromJson(body.toJson());
      expect(decoded.kind, BodyKind.json);
      expect(decoded.text, '{"a":1}');
    });

    test('unicode text round-trips', () {
      final body = CapturedBody.capture('héllo ✓ 日本語');
      final decoded = CapturedBody.fromJson(body.toJson());
      expect(decoded.text, 'héllo ✓ 日本語');
    });

    test('truncated body round-trips exactly (kind not re-derived)', () {
      final body = CapturedBody.capture('a' * 100, maxBytes: 10);
      expect(body.kind, BodyKind.truncated);
      final decoded = CapturedBody.fromJson(body.toJson());
      expect(decoded.kind, BodyKind.truncated);
      expect(decoded.text, 'a' * 10);
      expect(decoded.originalSize, 100);
      expect(decoded.truncated, isTrue);
    });

    test('image bytes round-trip via base64', () {
      final bytes = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final body = CapturedBody.image(
        bytes,
        originalSize: 32,
        truncated: false,
        contentType: 'image/png',
      );
      final decoded = CapturedBody.fromJson(body.toJson());
      expect(decoded.kind, BodyKind.image);
      expect(decoded.bytes, bytes);
      expect(decoded.contentType, 'image/png');
    });

    test('none round-trips', () {
      final decoded = CapturedBody.fromJson(CapturedBody.none.toJson());
      expect(decoded.kind, BodyKind.none);
    });

    test('bytes-only (metadata) round-trips without payload', () {
      final body = CapturedBody.captureBytes(
        List<int>.generate(20, (i) => i),
        contentType: 'application/octet-stream',
        maxBytes: 1024,
        captureImages: true,
      );
      final decoded = CapturedBody.fromJson(body.toJson());
      expect(decoded.kind, BodyKind.bytes);
      expect(decoded.bytes, isNull);
      expect(decoded.originalSize, 20);
    });

    test('unknown kind throws FormatException', () {
      expect(
        () => CapturedBody.fromJson(<String, Object?>{
          'kind': 'not-a-real-kind',
          'truncated': false,
        }),
        throwsFormatException,
      );
    });

    test('malformed base64 bytes throw FormatException', () {
      expect(
        () => CapturedBody.fromJson(<String, Object?>{
          'kind': 'image',
          'truncated': false,
          'bytes': 'not valid base64!!',
        }),
        throwsFormatException,
      );
    });
  });

  group('CapturedBody.captureRedacted', () {
    // Regression: body redaction used to be applied by each adapter only to
    // already-`String` bodies, so the Map/List and raw-bytes shapes — which
    // is what Dio's `data: {...}`, its default ResponseType.json, and
    // package:http hand over — silently bypassed it entirely.
    final JalaRedactor redactor = JalaRedactor();

    test('redacts a String body', () {
      final body = CapturedBody.captureRedacted(
        '{"user":"ada","password":"s3cret"}',
        redactor: redactor,
        contentType: 'application/json',
      );
      expect(body.text, '{"user":"ada","password":"••••••"}');
      expect(body.kind, BodyKind.json);
    });

    test('redacts an already-decoded Map body', () {
      final body = CapturedBody.captureRedacted(
        <String, dynamic>{'user': 'ada', 'password': 's3cret'},
        redactor: redactor,
      );
      expect(body.text, contains('••••••'));
      expect(body.text, isNot(contains('s3cret')));
      expect(body.kind, BodyKind.json);
    });

    test('redacts a List body', () {
      final body = CapturedBody.captureRedacted(
        <Object?>[
          <String, dynamic>{'access_token': 'abc.def'},
        ],
        redactor: redactor,
      );
      expect(body.text, isNot(contains('abc.def')));
    });

    test('redacts textual raw bytes', () {
      final body = CapturedBody.captureRedacted(
        utf8.encode('{"refresh_token":"r3fr3sh"}'),
        redactor: redactor,
        contentType: 'application/json',
      );
      expect(body.text, isNot(contains('r3fr3sh')));
    });

    test('applies custom redactedBodyPatterns', () {
      final body = CapturedBody.captureRedacted(
        <String, dynamic>{'ssn': '123-45-6789'},
        redactor: JalaRedactor(
          redactedBodyPatterns: <Pattern>[RegExp(r'\d{3}-\d{2}-\d{4}')],
        ),
      );
      expect(body.text, isNot(contains('123-45-6789')));
      expect(body.text, contains('••••••'));
    });

    test('non-textual bytes retain nothing, so there is nothing to redact', () {
      final body = CapturedBody.captureRedacted(
        <int>[0x00, 0x01, 0x02],
        redactor: redactor,
        contentType: 'application/octet-stream',
      );
      expect(body.kind, BodyKind.bytes);
      expect(body.text, isNull);
    });

    test('null and Stream bodies pass through unchanged', () {
      expect(
        CapturedBody.captureRedacted(null, redactor: redactor).kind,
        BodyKind.none,
      );
      expect(
        CapturedBody.captureRedacted(
          const Stream<List<int>>.empty(),
          redactor: redactor,
        ).kind,
        BodyKind.stream,
      );
    });

    test('the cap applies to the redacted text, not the raw body', () {
      final body = CapturedBody.captureRedacted(
        '{"password":"s3cret","pad":"${'x' * 400}"}',
        redactor: redactor,
        contentType: 'application/json',
        maxBytes: 64,
      );
      expect(body.kind, BodyKind.truncated);
      expect(body.truncated, isTrue);
      expect(utf8.encode(body.text!).length, lessThanOrEqualTo(64));
      // The mask survived truncation; the secret never entered the buffer.
      expect(body.text, contains('••••••'));
      expect(body.text, isNot(contains('s3cret')));
    });

    test('masking can bring an over-cap body back under it', () {
      // Not a bug: what gets retained really does fit, because the secret
      // was replaced before anything was measured. Documented so the
      // interaction with `knownTruncated` below is unambiguous.
      final body = CapturedBody.captureRedacted(
        '{"password":"${'x' * 400}"}',
        redactor: redactor,
        contentType: 'application/json',
        maxBytes: 64,
      );
      expect(body.kind, BodyKind.json);
      expect(body.truncated, isFalse);
      expect(body.text, '{"password":"••••••"}');
    });

    test('knownTruncated flags a body the caller already cut short', () {
      // Regression: jala_http forced truncation by passing a cap of
      // `buffered.length - 1`. Redaction shrinks the text, so the redacted
      // body could land back under that cap and be reported as complete.
      final body = CapturedBody.captureRedacted(
        '{"password":"s3cret-and-then-some-padding-to-shrink"}',
        redactor: redactor,
        contentType: 'application/json',
        maxBytes: 1024,
        knownTruncated: true,
      );
      expect(body.kind, BodyKind.truncated);
      expect(body.truncated, isTrue);
      expect(body.text, isNot(contains('s3cret')));
    });

    test('capture (unredacted) still retains what it is handed', () {
      // The non-redacting entry point is still used by import/session
      // decode, where content has already been through capture-time
      // redaction on the machine that recorded it.
      expect(
        CapturedBody.capture('{"password":"s3cret"}').text,
        '{"password":"s3cret"}',
      );
    });
  });
}
