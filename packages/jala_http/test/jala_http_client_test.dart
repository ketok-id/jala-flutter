import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jala_core/jala_core.dart';
import 'package:jala_http/jala_http.dart';
import 'package:test/test.dart';

import 'support/fake_http_client.dart';

/// Flushes pending microtasks so async event-bus deliveries settle.
Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  tearDown(JalaBinding.resetForTesting);

  group('JalaHttpClient requests', () {
    test('captures a successful JSON GET request and response', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeHttpClient fake = FakeHttpClient(
        (request) async =>
            jsonStreamedResponse(<String, dynamic>{'id': 1, 'name': 'ada'}),
      );
      final JalaHttpClient client = JalaHttpClient(inner: fake);

      final http.Response response = await client.get(
        Uri.parse('https://api.example.com/users/1'),
      );
      expect(response.statusCode, 200);
      await pump();

      final List<NetworkCallEntry> entries = JalaBinding.instance.store
          .entries;
      expect(entries, hasLength(1));
      final NetworkCallEntry entry = entries.single;
      expect(entry.method, 'GET');
      expect(entry.uri.toString(), 'https://api.example.com/users/1');
      expect(entry.client, 'http');
      expect(entry.status, JalaCallStatus.success);
      expect(entry.statusCode, 200);
      expect(entry.replayOf, isNull);
      expect(entry.responseBody.kind, BodyKind.json);
      expect(entry.responseBody.text, contains('"name":"ada"'));
      expect(entry.duration, isNotNull);
    });

    test('captures a successful JSON POST with a request body', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeHttpClient fake = FakeHttpClient(
        (request) async => jsonStreamedResponse(<String, dynamic>{
          'created': true,
        }, statusCode: 201),
      );
      final JalaHttpClient client = JalaHttpClient(inner: fake);

      final http.Response response = await client.post(
        Uri.parse('https://api.example.com/users'),
        body: jsonEncode(<String, dynamic>{'name': 'ada'}),
      );
      expect(response.statusCode, 201);
      await pump();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries
          .single;
      expect(entry.method, 'POST');
      expect(entry.statusCode, 201);
      expect(entry.requestBody.kind, BodyKind.json);
      expect(entry.requestBody.text, contains('"name":"ada"'));
    });

    test('redacts the Authorization header value in the store', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeHttpClient fake = FakeHttpClient(
        (request) async => jsonStreamedResponse(<String, dynamic>{'ok': true}),
      );
      final JalaHttpClient client = JalaHttpClient(inner: fake);

      await client.get(
        Uri.parse('https://api.example.com/secret'),
        headers: <String, String>{'Authorization': 'Bearer top-secret'},
      );
      await pump();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries
          .single;
      final String redacted = entry.requestHeaders.entries
          .firstWhere((e) => e.key.toLowerCase() == 'authorization')
          .value;
      expect(redacted, JalaRedactor.mask);

      // Redaction happens at capture time only — the real request sent
      // over the wire is unaffected.
      expect(fake.requests.single.headers['Authorization'], 'Bearer top-secret');
    });

    test(
      'captures a transport-level error and rethrows it unchanged',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final FakeHttpClient fake = FakeHttpClient(
          (request) async => throw Exception('network boom'),
        );
        final JalaHttpClient client = JalaHttpClient(inner: fake);

        await expectLater(
          () => client.get(Uri.parse('https://api.example.com/broken')),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('network boom'),
            ),
          ),
        );
        await pump();

        final NetworkCallEntry entry = JalaBinding.instance.store.entries
            .single;
        expect(entry.status, JalaCallStatus.error);
        expect(entry.errorMessage, contains('network boom'));
        expect(entry.duration, isNotNull);
      },
    );

    test(
      'disabled binding: client emits nothing and the request still '
      'succeeds',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: false));
        final FakeHttpClient fake = FakeHttpClient(
          (request) async => jsonStreamedResponse(<String, dynamic>{
            'ok': true,
          }),
        );
        final JalaHttpClient client = JalaHttpClient(inner: fake);

        final http.Response response = await client.get(
          Uri.parse('https://api.example.com/ping'),
        );
        expect(response.statusCode, 200);
        await pump();
        expect(JalaBinding.instance.store.entries, isEmpty);
      },
    );

    test(
      'never-initialized binding: request still succeeds with zero '
      'capture work',
      () async {
        // Deliberately never call JalaBinding.instance.initialize().
        final FakeHttpClient fake = FakeHttpClient(
          (request) async => jsonStreamedResponse(<String, dynamic>{
            'ok': true,
          }),
        );
        final JalaHttpClient client = JalaHttpClient(inner: fake);

        final http.Response response = await client.get(
          Uri.parse('https://api.example.com/ping'),
        );
        expect(response.statusCode, 200);
        expect(JalaBinding.instance.isInitialized, isFalse);
      },
    );

    test(
      'truncates a response body larger than maxBodyBytes while still '
      'delivering the full body to the caller',
      () async {
        JalaBinding.instance.initialize(
          config: JalaConfig(enabled: true, maxBodyBytes: 64),
        );
        final String big = 'x' * 5000;
        final List<int> fullBytes = utf8.encode(
          jsonEncode(<String, dynamic>{'data': big}),
        );
        final FakeHttpClient fake = FakeHttpClient(
          (request) async => jsonStreamedResponse(<String, dynamic>{
            'data': big,
          }),
        );
        final JalaHttpClient client = JalaHttpClient(inner: fake);

        final http.StreamedResponse streamed = await client.send(
          http.Request('GET', Uri.parse('https://api.example.com/large')),
        );
        final List<int> received = await streamed.stream
            .expand((chunk) => chunk)
            .toList();
        // The caller must receive the complete, untruncated body.
        expect(received, fullBytes);

        await pump();
        final NetworkCallEntry entry = JalaBinding.instance.store.entries
            .single;
        expect(entry.responseBody.kind, BodyKind.truncated);
        expect(entry.responseBody.truncated, isTrue);
        expect(entry.responseBody.originalSize, greaterThan(0));
        // The true total size is carried by the entry's own `responseSize`
        // field (independent of `CapturedBody.originalSize`, which only
        // reflects the bounded capture buffer — see the SPEC-NOTE in
        // `JalaHttpClient._buildResponseBody`).
        expect(entry.responseSize, fullBytes.length);
      },
    );

    test(
      'delivers a slow/chunked response stream to the caller unmodified '
      'while capturing it',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final List<List<int>> chunks = <List<int>>[
          utf8.encode('{"chunk":1,'),
          utf8.encode('"chunk2":2,'),
          utf8.encode('"chunk3":3}'),
        ];
        final FakeHttpClient fake = FakeHttpClient(
          (request) async => chunkedStreamedResponse(
            chunks,
            headers: <String, String>{'content-type': 'application/json'},
            delayBetweenChunks: const Duration(milliseconds: 5),
          ),
        );
        final JalaHttpClient client = JalaHttpClient(inner: fake);

        final http.StreamedResponse streamed = await client.send(
          http.Request('GET', Uri.parse('https://api.example.com/chunked')),
        );
        final List<List<int>> received = await streamed.stream.toList();
        expect(received, chunks);

        await pump();
        final NetworkCallEntry entry = JalaBinding.instance.store.entries
            .single;
        expect(entry.responseBody.kind, BodyKind.json);
        expect(
          entry.responseBody.text,
          '{"chunk":1,"chunk2":2,"chunk3":3}',
        );
        expect(entry.responseSize, 33);
      },
    );

    test(
      'summarizes MultipartRequest fields and file metadata without '
      'reading file bytes',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final FakeHttpClient fake = FakeHttpClient(
          (request) async => jsonStreamedResponse(<String, dynamic>{
            'ok': true,
          }),
        );
        final JalaHttpClient client = JalaHttpClient(inner: fake);

        final http.MultipartRequest request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.example.com/upload'),
        )..fields['name'] = 'ada';
        request.files.add(
          http.MultipartFile.fromString(
            'avatar',
            'binarydata',
            filename: 'avatar.png',
          ),
        );

        await client.send(request);
        await pump();

        final NetworkCallEntry entry = JalaBinding.instance.store.entries
            .single;
        expect(entry.requestBody.kind, BodyKind.json);
        final Map<String, dynamic> decoded =
            jsonDecode(entry.requestBody.text!) as Map<String, dynamic>;
        expect(decoded['fields'], <Map<String, String>>[
          {'name': 'name', 'value': 'ada'},
        ]);
        final List<dynamic> files = decoded['files'] as List<dynamic>;
        expect(files, hasLength(1));
        final Map<String, dynamic> file = files.single as Map<String, dynamic>;
        expect(file['filename'], 'avatar.png');
        expect(file['length'], 'binarydata'.length);
      },
    );

    test(
      'captures a StreamedRequest body as metadata only, without '
      'consuming its sink',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final FakeHttpClient fake = FakeHttpClient(
          (request) async => jsonStreamedResponse(<String, dynamic>{
            'ok': true,
          }),
        );
        final JalaHttpClient client = JalaHttpClient(inner: fake);

        final http.StreamedRequest request = http.StreamedRequest(
          'POST',
          Uri.parse('https://api.example.com/stream-upload'),
        );
        request.sink.add(utf8.encode('streamed body'));
        unawaited(request.sink.close());

        await client.send(request);
        await pump();

        final NetworkCallEntry entry = JalaBinding.instance.store.entries
            .single;
        expect(entry.requestBody.kind, BodyKind.stream);
        expect(entry.requestBody.text, isNull);
      },
    );
  });
}
