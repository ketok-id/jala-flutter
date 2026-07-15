import 'dart:convert';

import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('CurlExporter', () {
    test('basic GET', () {
      final entry = makeEntry(url: 'https://api.example.com/users?page=1');
      expect(
        CurlExporter.export(entry),
        "curl -X GET \\\n  'https://api.example.com/users?page=1'",
      );
    });

    test('POST with headers, body, and --compressed', () {
      final entry = makeEntry(
        method: 'POST',
        url: 'https://api.example.com/users',
        requestHeaders: const {
          'content-type': 'application/json',
          'accept-encoding': 'gzip, deflate',
        },
        requestBody: CapturedBody.capture('{"name":"ada"}',
            contentType: 'application/json'),
      );
      expect(CurlExporter.export(entry), '''
curl -X POST \\
  'https://api.example.com/users' \\
  -H 'content-type: application/json' \\
  -H 'accept-encoding: gzip, deflate' \\
  --compressed \\
  -d '{"name":"ada"}\'''');
    });

    test('single quotes in body are shell-escaped', () {
      final entry = makeEntry(
        method: 'POST',
        requestBody: CapturedBody.capture("{\"name\":\"O'Brien\"}",
            contentType: 'application/json'),
      );
      final curl = CurlExporter.export(entry);
      // Expected shell text: -d '{"name":"O'\''Brien"}'
      const expected = "-d '" '{"name":"O' r"'\''" 'Brien"}' "'";
      expect(curl, contains(expected));
    });

    test('unicode passes through unmangled inside single quotes', () {
      final entry = makeEntry(
        method: 'POST',
        requestBody:
            CapturedBody.capture('{"city":"日本 – Ōsaka ✓"}',
                contentType: 'application/json'),
      );
      expect(CurlExporter.export(entry), contains('日本 – Ōsaka ✓'));
    });

    test('single quotes in header values are shell-escaped', () {
      final entry = makeEntry(
        requestHeaders: const {'x-note': "it's"},
      );
      expect(CurlExporter.export(entry), contains(r"-H 'x-note: it'\''s'"));
    });

    test('no --compressed without gzip accept-encoding', () {
      final entry = makeEntry(
        requestHeaders: const {'accept-encoding': 'identity'},
      );
      expect(CurlExporter.export(entry), isNot(contains('--compressed')));
    });

    test('redacted: true keeps masked header placeholders', () {
      final entry = makeEntry(
        requestHeaders: {'authorization': JalaRedactor.mask},
      );
      expect(
        CurlExporter.export(entry),
        contains('authorization: ${JalaRedactor.mask}'),
      );
    });

    test('redacted: false drops masked headers entirely', () {
      final entry = makeEntry(
        requestHeaders: {
          'authorization': JalaRedactor.mask,
          'accept': 'application/json',
        },
      );
      final curl = CurlExporter.export(entry, redacted: false);
      expect(curl, isNot(contains('authorization')));
      expect(curl, contains("-H 'accept: application/json'"));
    });
  });

  group('DartSnippetExporter', () {
    test('renders a runnable dio.request snippet', () {
      final entry = makeEntry(
        method: 'POST',
        url: 'https://api.example.com/users',
        requestHeaders: const {'content-type': 'application/json'},
        requestBody: CapturedBody.capture('{"name":"ada"}',
            contentType: 'application/json'),
      );
      expect(DartSnippetExporter.export(entry), '''
final dio = Dio();
final response = await dio.request(
  'https://api.example.com/users',
  options: Options(
    method: 'POST',
    headers: {
      'content-type': 'application/json',
    },
  ),
  data: jsonDecode('{"name":"ada"}'),
);
print(response.data);''');
    });

    test('GET without headers or body stays minimal', () {
      final entry = makeEntry(url: 'https://x.dev/a');
      expect(DartSnippetExporter.export(entry), '''
final dio = Dio();
final response = await dio.request(
  'https://x.dev/a',
  options: Options(
    method: 'GET',
  ),
);
print(response.data);''');
    });

    test('non-JSON body is passed as a plain string', () {
      final entry = makeEntry(
        method: 'POST',
        requestBody: CapturedBody.capture('a=1&b=2',
            contentType: 'application/x-www-form-urlencoded'),
      );
      expect(
        DartSnippetExporter.export(entry),
        contains("data: 'a=1&b=2',"),
      );
    });

    test(r'escapes quotes, dollars, and newlines in Dart strings', () {
      final entry = makeEntry(
        method: 'POST',
        requestHeaders: const {'x-note': r"it's $var"},
        requestBody:
            CapturedBody.capture('line1\nline2', contentType: 'text/plain'),
      );
      final snippet = DartSnippetExporter.export(entry);
      expect(snippet, contains(r"'x-note': 'it\'s \$var',"));
      expect(snippet, contains(r"data: 'line1\nline2',"));
    });
  });

  group('HarExporter', () {
    Map<String, Object?> decode(String har) =>
        (jsonDecode(har) as Map).cast<String, Object?>();

    test('session export has required HAR 1.2 log fields', () {
      final har = decode(HarExporter.exportSession([makeEntry(), makeEntry(id: 'b')]));
      final log = (har['log'] as Map).cast<String, Object?>();

      expect(log['version'], '1.2');
      final creator = (log['creator'] as Map).cast<String, Object?>();
      expect(creator['name'], 'jala');
      expect(creator['version'], '0.1.0');
      expect(log['entries'], hasLength(2));
    });

    test('entry has required request/response/timings fields', () {
      final entry = makeEntry(
        method: 'POST',
        url: 'https://api.example.com/users?page=2&sort=asc',
        startTime: DateTime.utc(2026, 7, 15, 10, 30),
        requestHeaders: const {'content-type': 'application/json'},
        requestBody: CapturedBody.capture('{"a":1}',
            contentType: 'application/json'),
        statusCode: 201,
        statusMessage: 'Created',
        responseHeaders: const {'content-type': 'application/json'},
        responseBody: CapturedBody.capture('{"id":9}',
            contentType: 'application/json'),
        duration: const Duration(milliseconds: 345),
        requestSize: 7,
        responseSize: 8,
      );
      final har = decode(HarExporter.exportCall(entry));
      final log = (har['log'] as Map).cast<String, Object?>();
      final harEntry =
          ((log['entries'] as List).single as Map).cast<String, Object?>();

      expect(harEntry['startedDateTime'], '2026-07-15T10:30:00.000Z');
      expect(harEntry['time'], 345);
      expect(harEntry['cache'], isEmpty);

      final request = (harEntry['request'] as Map).cast<String, Object?>();
      expect(request['method'], 'POST');
      expect(request['url'], 'https://api.example.com/users?page=2&sort=asc');
      expect(request['httpVersion'], 'HTTP/1.1');
      expect(request['cookies'], isEmpty);
      expect(request['headers'], [
        {'name': 'content-type', 'value': 'application/json'},
      ]);
      expect(
        request['queryString'],
        containsAll([
          {'name': 'page', 'value': '2'},
          {'name': 'sort', 'value': 'asc'},
        ]),
      );
      expect(request['headersSize'], -1);
      expect(request['bodySize'], 7);
      final postData = (request['postData'] as Map).cast<String, Object?>();
      expect(postData['mimeType'], 'application/json');
      expect(postData['text'], '{"a":1}');

      final response = (harEntry['response'] as Map).cast<String, Object?>();
      expect(response['status'], 201);
      expect(response['statusText'], 'Created');
      expect(response['httpVersion'], 'HTTP/1.1');
      expect(response['cookies'], isEmpty);
      expect(response['redirectURL'], '');
      expect(response['headersSize'], -1);
      expect(response['bodySize'], 8);
      final content = (response['content'] as Map).cast<String, Object?>();
      expect(content['size'], 8);
      expect(content['mimeType'], 'application/json');
      expect(content['text'], '{"id":9}');

      final timings = (harEntry['timings'] as Map).cast<String, Object?>();
      expect(timings['send'], -1);
      expect(timings['receive'], -1);
      expect(timings['wait'], 345);
    });

    test('pending call exports without throwing', () {
      final pending = makeEntry(
        statusCode: null,
        statusMessage: null,
        status: JalaCallStatus.pending,
        duration: null,
        responseSize: null,
        responseHeaders: const {},
      );
      final har = decode(HarExporter.exportCall(pending));
      final log = (har['log'] as Map).cast<String, Object?>();
      final harEntry =
          ((log['entries'] as List).single as Map).cast<String, Object?>();
      expect(harEntry['time'], 0);
      final response = (harEntry['response'] as Map).cast<String, Object?>();
      expect(response['status'], 0);
      expect(response['statusText'], '');
    });

    test('redirect location is exposed as redirectURL', () {
      final entry = makeEntry(
        statusCode: 302,
        responseHeaders: const {'Location': 'https://x.dev/next'},
      );
      final har = decode(HarExporter.exportCall(entry));
      final log = (har['log'] as Map).cast<String, Object?>();
      final harEntry =
          ((log['entries'] as List).single as Map).cast<String, Object?>();
      final response = (harEntry['response'] as Map).cast<String, Object?>();
      expect(response['redirectURL'], 'https://x.dev/next');
    });

    test('output is pretty-printed valid JSON', () {
      final har = HarExporter.exportSession([makeEntry()]);
      expect(har, contains('\n'));
      expect(() => jsonDecode(har), returnsNormally);
    });
  });
}
