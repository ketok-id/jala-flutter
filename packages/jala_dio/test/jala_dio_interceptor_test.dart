import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_dio/jala_dio.dart';
import 'package:test/test.dart';

import 'support/fake_http_client_adapter.dart';

/// A value whose [toString] blows up — used to simulate a bug in Jala's
/// own capture logic (e.g. a header value that can't be stringified)
/// without ever touching `jala_core`.
class _ThrowsOnToString {
  const _ThrowsOnToString();

  @override
  String toString() => throw StateError('capture boom');
}

/// Flushes pending microtasks so async event-bus deliveries settle.
Future<void> pump() => Future<void>.delayed(Duration.zero);

({Dio dio, FakeHttpClientAdapter adapter}) buildDio(
  FutureOr<ResponseBody> Function(RequestOptions options) handler,
) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(handler);
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(JalaDioInterceptor());
  return (dio: dio, adapter: adapter);
}

void main() {
  tearDown(JalaBinding.resetForTesting);

  group('JalaDioInterceptor requests', () {
    test('captures a successful JSON GET request and response', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final harness = buildDio(
        (options) async => jsonResponseBody(<String, dynamic>{
          'id': 1,
          'name': 'ada',
        }),
      );

      final Response<dynamic> response = await harness.dio.get<dynamic>(
        '/users/1',
      );
      expect(response.statusCode, 200);
      await pump();

      final List<NetworkCallEntry> entries = JalaBinding.instance.store
          .entries;
      expect(entries, hasLength(1));
      final NetworkCallEntry entry = entries.single;
      expect(entry.method, 'GET');
      expect(entry.uri.toString(), 'https://api.example.com/users/1');
      expect(entry.client, 'dio');
      expect(entry.status, JalaCallStatus.success);
      expect(entry.statusCode, 200);
      expect(entry.replayOf, isNull);
      expect(entry.responseBody.kind, BodyKind.json);
      expect(entry.responseBody.text, contains('"name":"ada"'));
      expect(entry.duration, isNotNull);
    });

    test('captures a successful JSON POST with a request body', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final harness = buildDio(
        (options) async =>
            jsonResponseBody(<String, dynamic>{'created': true}, statusCode: 201),
      );

      final Response<dynamic> response = await harness.dio.post<dynamic>(
        '/users',
        data: <String, dynamic>{'name': 'ada'},
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
      final harness = buildDio(
        (options) async => jsonResponseBody(<String, dynamic>{'ok': true}),
      );

      await harness.dio.get<dynamic>(
        '/secret',
        options: Options(headers: {'Authorization': 'Bearer top-secret'}),
      );
      await pump();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries
          .single;
      final String redacted = entry.requestHeaders.entries
          .firstWhere((e) => e.key.toLowerCase() == 'authorization')
          .value;
      expect(redacted, JalaRedactor.mask);

      // Redaction happens at capture time only — the real request sent
      // over the wire is unaffected. (Replayed requests dropping the
      // masked value entirely is covered by the replay test.)
      expect(
        harness.adapter.requests.single.headers['Authorization'],
        'Bearer top-secret',
      );
    });

    test('captures a 500 error response as status error with body', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final harness = buildDio(
        (options) async => jsonResponseBody(
          <String, dynamic>{'error': 'boom'},
          statusCode: 500,
          statusMessage: 'Internal Server Error',
        ),
      );

      await expectLater(
        () => harness.dio.get<dynamic>('/broken'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
      await pump();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries
          .single;
      expect(entry.status, JalaCallStatus.error);
      expect(entry.statusCode, 500);
      expect(entry.errorMessage, isNotNull);
      expect(entry.responseBody.kind, BodyKind.json);
      expect(entry.responseBody.text, contains('boom'));
    });

    test('captures cancellation as JalaCallStatus.cancelled', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final harness = buildDio(
        (options) async => throw DioException.requestCancelled(
          requestOptions: options,
          reason: 'test cancel',
        ),
      );

      await expectLater(
        () => harness.dio.get<dynamic>('/cancel-me'),
        throwsA(isA<DioException>()),
      );
      await pump();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries
          .single;
      expect(entry.status, JalaCallStatus.cancelled);
    });

    test(
      'captures ResponseType.bytes as metadata-only (no decoded content)',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final List<int> bytes = List<int>.generate(64, (i) => i % 256);
        final harness = buildDio(
          (options) async => ResponseBody.fromBytes(
            bytes,
            200,
            headers: <String, List<String>>{
              'content-type': <String>['application/octet-stream'],
            },
          ),
        );

        await harness.dio.get<dynamic>(
          '/blob',
          options: Options(responseType: ResponseType.bytes),
        );
        await pump();

        final NetworkCallEntry entry = JalaBinding.instance.store.entries
            .single;
        expect(entry.responseBody.kind, BodyKind.bytes);
        expect(entry.responseBody.text, isNull);
        expect(entry.responseBody.originalSize, bytes.length);
      },
    );

    test('captures ResponseType.stream as metadata-only', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final harness = buildDio(
        (options) async =>
            jsonResponseBody(<String, dynamic>{'big': 'x' * 200}),
      );

      await harness.dio.get<dynamic>(
        '/stream-me',
        options: Options(responseType: ResponseType.stream),
      );
      await pump();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries
          .single;
      expect(entry.responseBody.kind, BodyKind.stream);
      expect(entry.responseBody.text, isNull);
    });

    test('truncates a response body larger than maxBodyBytes', () async {
      JalaBinding.instance.initialize(
        config: JalaConfig(enabled: true, maxBodyBytes: 64),
      );
      final String big = 'x' * 5000;
      final harness = buildDio(
        (options) async => jsonResponseBody(<String, dynamic>{'data': big}),
      );

      await harness.dio.get<dynamic>('/large');
      await pump();

      final NetworkCallEntry entry = JalaBinding.instance.store.entries
          .single;
      expect(entry.responseBody.kind, BodyKind.truncated);
      expect(entry.responseBody.truncated, isTrue);
      expect(entry.responseBody.originalSize, greaterThan(64));
    });

    test(
      'disabled binding: interceptor emits nothing and the request '
      'still succeeds',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: false));
        final harness = buildDio(
          (options) async => jsonResponseBody(<String, dynamic>{'ok': true}),
        );

        final Response<dynamic> response = await harness.dio.get<dynamic>(
          '/ping',
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
        final harness = buildDio(
          (options) async => jsonResponseBody(<String, dynamic>{'ok': true}),
        );

        final Response<dynamic> response = await harness.dio.get<dynamic>(
          '/ping',
        );
        expect(response.statusCode, 200);
        expect(JalaBinding.instance.isInitialized, isFalse);
      },
    );

    test(
      'a capture bug (header value whose toString() throws) does not '
      'break the request',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final harness = buildDio(
          (options) async => jsonResponseBody(<String, dynamic>{'ok': true}),
        );

        final Response<dynamic> response = await harness.dio.get<dynamic>(
          '/ping',
          options: Options(
            headers: <String, dynamic>{'x-weird': const _ThrowsOnToString()},
          ),
        );

        expect(response.statusCode, 200);
        await pump();
        // The request-side capture blew up before the request event was
        // emitted, so nothing landed in the store for this call — the
        // important part is that the app's networking was unaffected.
        expect(JalaBinding.instance.store.entries, isEmpty);
      },
    );

    test(
      'summarizes FormData fields and file metadata without reading '
      'file bytes',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final FormData formData = FormData()
          ..fields.add(const MapEntry<String, String>('name', 'ada'))
          ..files.add(
            MapEntry<String, MultipartFile>(
              'avatar',
              MultipartFile.fromString('binarydata', filename: 'avatar.png'),
            ),
          );

        final harness = buildDio(
          (options) async => jsonResponseBody(<String, dynamic>{'ok': true}),
        );
        await harness.dio.post<dynamic>('/upload', data: formData);
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
  });
}
