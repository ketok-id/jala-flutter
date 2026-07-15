import 'dart:async';

import 'package:dio/dio.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_dio/jala_dio.dart';
import 'package:test/test.dart';

import 'support/fake_http_client_adapter.dart';

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  tearDown(JalaBinding.resetForTesting);

  group('JalaDio.attach + JalaDioReplayer', () {
    test('attach registers both the interceptor and a replayer', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.httpClientAdapter = FakeHttpClientAdapter(
        (options) async => jsonResponseBody(<String, dynamic>{'ok': true}),
      );

      JalaDio.attach(dio);

      expect(
        dio.interceptors.whereType<JalaDioInterceptor>(),
        hasLength(1),
      );
      expect(JalaBinding.instance.replayRegistry.hasReplayer, isTrue);
    });

    test(
      'replaying an entry issues a new request and the store gains a '
      'new entry with replayOf set, without resending the masked header',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
          (options) async => jsonResponseBody(<String, dynamic>{'ok': true}),
        );
        final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
          ..httpClientAdapter = adapter;
        JalaDio.attach(dio);

        await dio.get<dynamic>(
          '/users/1',
          options: Options(headers: {'Authorization': 'Bearer top-secret'}),
        );
        await pump();

        expect(JalaBinding.instance.store.entries, hasLength(1));
        final NetworkCallEntry original = JalaBinding.instance.store.entries
            .single;
        expect(original.replayOf, isNull);

        final bool replayed = await JalaBinding.instance.replayRegistry
            .replay(original);
        expect(replayed, isTrue);
        await pump();

        final List<NetworkCallEntry> entries = JalaBinding.instance.store
            .entries;
        expect(entries, hasLength(2));

        // Newest first: the replay is now at the front.
        final NetworkCallEntry replayEntry = entries.first;
        expect(replayEntry.id, isNot(original.id));
        expect(replayEntry.replayOf, original.id);
        expect(replayEntry.method, 'GET');
        expect(replayEntry.uri, original.uri);

        // The masked Authorization value must never be resent over the
        // wire on replay.
        expect(adapter.requests, hasLength(2));
        final RequestOptions replayedRequest = adapter.requests.last;
        expect(
          replayedRequest.headers.keys
              .map((k) => k.toLowerCase())
              .contains('authorization'),
          isFalse,
        );
      },
    );

    test('replaying a JSON request body re-encodes it as decoded JSON', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        (options) async => jsonResponseBody(<String, dynamic>{'ok': true}),
      );
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = adapter;
      JalaDio.attach(dio);

      await dio.post<dynamic>('/users', data: <String, dynamic>{'name': 'ada'});
      await pump();

      final NetworkCallEntry original = JalaBinding.instance.store.entries
          .single;
      await JalaBinding.instance.replayRegistry.replay(original);
      await pump();

      expect(adapter.requests, hasLength(2));
      final RequestOptions replayedRequest = adapter.requests.last;
      expect(replayedRequest.data, <String, dynamic>{'name': 'ada'});
    });

    test('replaying a failing call is swallowed by the replayer', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      int calls = 0;
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter((
        options,
      ) async {
        calls++;
        return jsonResponseBody(<String, dynamic>{'error': 'boom'}, statusCode: 500);
      });
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = adapter;
      JalaDio.attach(dio);

      await expectLater(
        () => dio.get<dynamic>('/broken'),
        throwsA(isA<DioException>()),
      );
      await pump();
      expect(calls, 1);

      final NetworkCallEntry original = JalaBinding.instance.store.entries
          .single;
      // Must not throw, even though the replayed call itself fails.
      await JalaBinding.instance.replayRegistry.replay(original);
      await pump();

      expect(calls, 2);
      final List<NetworkCallEntry> entries = JalaBinding.instance.store
          .entries;
      expect(entries, hasLength(2));
      expect(entries.first.status, JalaCallStatus.error);
      expect(entries.first.replayOf, original.id);
    });
  });
}
