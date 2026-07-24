import 'dart:convert';

import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('JalaCurlCodec', () {
    test('parses a bare GET', () {
      final ImportedRequest req = JalaCurlCodec.decode(
        'curl https://api.example.com/users?page=1',
      );
      expect(req.method, 'GET');
      expect(req.uri, Uri.parse('https://api.example.com/users?page=1'));
      expect(req.headers, isEmpty);
      expect(req.body, isNull);
    });

    test('parses method, headers and a JSON body', () {
      final ImportedRequest req = JalaCurlCodec.decode(
        "curl -X POST https://api.example.com/post "
        "-H 'Content-Type: application/json' "
        "-H 'X-Trace: abc' "
        r"""-d '{"hello":"jala"}'""",
      );
      expect(req.method, 'POST');
      expect(req.headers['Content-Type'], 'application/json');
      expect(req.headers['X-Trace'], 'abc');
      expect(req.body, '{"hello":"jala"}');
    });

    test('infers POST when data is present and no method is given', () {
      final ImportedRequest req = JalaCurlCodec.decode(
        "curl https://api.example.com/form --data 'a=b'",
      );
      expect(req.method, 'POST');
      expect(req.body, 'a=b');
    });

    test('handles `\\`-newline line continuations', () {
      final ImportedRequest req = JalaCurlCodec.decode(
        'curl https://api.example.com/x \\\n'
        "  -H 'Accept: application/json' \\\n"
        '  --compressed',
      );
      expect(req.uri.path, '/x');
      expect(req.headers['Accept'], 'application/json');
    });

    test("round-trips the exporter's '\\'' single-quote escaping", () {
      // A header value containing a single quote, as CurlExporter emits it.
      final ImportedRequest req = JalaCurlCodec.decode(
        r"curl https://x.test -H 'X-Note: it'\''s fine'",
      );
      expect(req.headers['X-Note'], "it's fine");
    });

    test('-u becomes a Basic Authorization header', () {
      final ImportedRequest req = JalaCurlCodec.decode(
        'curl https://x.test -u alice:secret',
      );
      expect(
        req.headers['Authorization'],
        'Basic ${base64.encode(utf8.encode('alice:secret'))}',
      );
    });

    test('a real URL wins over a stray bare argument', () {
      // `--max-time 5` is unknown; 5 is a bare token but must not become the
      // URL when a scheme-bearing token is present.
      final ImportedRequest req = JalaCurlCodec.decode(
        'curl --max-time 5 https://api.example.com/x',
      );
      expect(req.uri, Uri.parse('https://api.example.com/x'));
    });

    test('throws JalaImportFormatException when no URL is present', () {
      expect(
        () => JalaCurlCodec.decode('curl -X POST -H "Accept: */*"'),
        throwsA(isA<JalaImportFormatException>()),
      );
    });
  });

  group('JalaHarCodec', () {
    test('round-trips a HarExporter document', () {
      final NetworkCallEntry entry = makeEntry(
        method: 'POST',
        url: 'https://api.example.com/post',
        statusCode: 201,
        requestHeaders: const <String, String>{'x-trace': 'abc'},
        requestBody: CapturedBody.capture(
          <String, Object?>{'hello': 'jala'},
          contentType: 'application/json',
        ),
        responseBody: CapturedBody.capture(
          <String, Object?>{'ok': true},
          contentType: 'application/json',
        ),
      );
      final String har = HarExporter.exportCall(entry);

      final JalaSession session = JalaHarCodec.decode(har);
      expect(session.entries, hasLength(1));
      final NetworkCallEntry decoded = session.entries.single;
      expect(decoded.method, 'POST');
      expect(decoded.uri, Uri.parse('https://api.example.com/post'));
      expect(decoded.statusCode, 201);
      expect(decoded.requestHeaders['x-trace'], 'abc');
      expect(decoded.responseBody.text, '{"ok":true}');
      // Imported entries are flagged so the UI disables replay.
      expect(decoded.imported, isTrue);
      expect(decoded.client, 'har');
    });

    test('malformed JSON throws JalaSessionFormatException', () {
      expect(
        () => JalaHarCodec.decode('{not json'),
        throwsA(isA<JalaSessionFormatException>()),
      );
    });

    test('a document without a log object throws', () {
      expect(
        () => JalaHarCodec.decode('{"notlog": 1}'),
        throwsA(isA<JalaSessionFormatException>()),
      );
    });

    test('parses a minimal hand-written HAR entry', () {
      const String har = '''
{"log":{"version":"1.2","entries":[
  {"startedDateTime":"2026-07-24T10:00:00.000Z","time":42,
   "request":{"method":"GET","url":"https://api.example.com/x","headers":[{"name":"Accept","value":"application/json"}]},
   "response":{"status":200,"statusText":"OK","headers":[],"content":{"size":13,"mimeType":"application/json","text":"{\\"a\\":1}"}}}
]}}''';
      final JalaSession session = JalaHarCodec.decode(har);
      final NetworkCallEntry decoded = session.entries.single;
      expect(decoded.method, 'GET');
      expect(decoded.statusCode, 200);
      expect(decoded.requestHeaders['Accept'], 'application/json');
      expect(decoded.responseBody.text, '{"a":1}');
      expect(decoded.duration, const Duration(milliseconds: 42));
    });
  });
}
