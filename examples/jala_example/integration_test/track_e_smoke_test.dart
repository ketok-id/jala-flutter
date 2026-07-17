// Store-only Track E smoke (no inspector UI) — throttling + session codec.
//
// Throttle drop uses the offline profile (no network). Latency uses a
// synthetic 200ms profile against a mock short-circuit so we never depend
// on a slow host. Codec round-trip encodes whatever is in the store after
// those steps and re-imports it.
//
// Prints a step marker before each await so hangs are diagnosable — same
// convention as track_c_smoke_test.dart / track_d_smoke_test.dart.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_dio/jala_dio.dart';

void step(String msg) {
  // ignore: avoid_print
  print('TRACK_E_SMOKE: $msg');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2 throttle drop + latency store-only', (
    WidgetTester tester,
  ) async {
    step('1 initialize binding');
    JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
    addTearDown(JalaBinding.resetForTesting);

    step('2 attach dio');
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
      ),
    );
    JalaDio.attach(dio);

    step('3 offline profile — 100% drop, no adapter hit');
    JalaBinding.instance.throttleRegistry.setActive(
      JalaThrottleProfile.offline,
    );
    await expectLater(
      dio.get<dynamic>('https://postman-echo.com/get?smoke=throttle-drop'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();

    final NetworkCallEntry dropEntry = JalaBinding.instance.store.entries
        .firstWhere(
          (NetworkCallEntry e) => e.throttledBy == 'offline',
          orElse: () => throw StateError(
            'no throttledBy=offline entry; '
            '${JalaBinding.instance.store.entries.map((e) => '${e.uri} t=${e.throttledBy} s=${e.status}').toList()}',
          ),
        );
    expect(dropEntry.status, JalaCallStatus.error);
    step('4 drop entry status=error throttledBy=offline');

    step('5 mock + 200ms latency profile (no real network)');
    JalaBinding.instance.store.clear();
    JalaBinding.instance.throttleRegistry.setActive(
      const JalaThrottleProfile(
        id: 'smoke-latency',
        name: 'Smoke Latency',
        latencyMs: 200,
      ),
    );
    JalaBinding.instance.mockRegistry.clear();
    JalaBinding.instance.mockRegistry.add(
      const JalaMockRule(
        id: 'smoke-latency-mock',
        name: 'smoke latency get',
        method: 'GET',
        urlPattern: 'https://postman-echo.com/get*',
        action: MockResponse(
          statusCode: 200,
          headers: <String, String>{'content-type': 'application/json'},
          body: '{"jala_smoke":true,"source":"throttle-latency"}',
        ),
      ),
    );

    final Stopwatch sw = Stopwatch()..start();
    final Response<dynamic> response = await dio
        .get<dynamic>(
          'https://postman-echo.com/get',
          queryParameters: <String, dynamic>{'smoke': 'throttle-latency'},
        )
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw TimeoutException(
            'dio.get hung under latency throttle',
          ),
        );
    sw.stop();
    step('6 latency request returned in ${sw.elapsedMilliseconds}ms');

    expect(response.statusCode, 200);
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(150));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();

    final NetworkCallEntry latencyEntry = JalaBinding.instance.store.entries
        .firstWhere(
          (NetworkCallEntry e) => e.throttledBy == 'smoke-latency',
          orElse: () => throw StateError(
            'no throttledBy=smoke-latency entry; '
            '${JalaBinding.instance.store.entries.map((e) => '${e.uri} t=${e.throttledBy}').toList()}',
          ),
        );
    expect(latencyEntry.status, JalaCallStatus.success);
    expect(latencyEntry.mockRuleId, 'smoke-latency-mock');

    step('7 clear throttle');
    JalaBinding.instance.throttleRegistry.clear();
    step('8 PASS');
  });

  testWidgets('E1 session codec round-trip store-only', (
    WidgetTester tester,
  ) async {
    step('1 initialize binding');
    JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
    addTearDown(JalaBinding.resetForTesting);

    step('2 seed store via mock capture');
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    JalaDio.attach(dio);
    JalaBinding.instance.mockRegistry.add(
      const JalaMockRule(
        id: 'smoke-codec-mock',
        name: 'smoke codec get',
        method: 'GET',
        urlPattern: 'https://postman-echo.com/get*',
        action: MockResponse(
          statusCode: 200,
          headers: <String, String>{'content-type': 'application/json'},
          body: '{"jala_smoke":true,"source":"codec"}',
        ),
      ),
    );
    await dio.get<dynamic>(
      'https://postman-echo.com/get',
      queryParameters: <String, dynamic>{'smoke': 'codec'},
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();

    final int liveCount = JalaBinding.instance.store.entries.length;
    expect(liveCount, greaterThanOrEqualTo(1));
    step('3 live entries=$liveCount');

    step('4 encode → decode → import (replace)');
    final String encoded = JalaSessionCodec.encode(JalaBinding.instance.store);
    expect(encoded, contains('jala-session'));
    final JalaSession session = JalaSessionCodec.decode(encoded);
    expect(session.entries, hasLength(liveCount));

    JalaBinding.instance.store.importSession(session);
    await tester.pump();

    expect(JalaBinding.instance.store.isViewingImport, isTrue);
    expect(JalaBinding.instance.store.entries, hasLength(liveCount));
    expect(
      JalaBinding.instance.store.entries.every(
        (NetworkCallEntry e) => e.imported,
      ),
      isTrue,
    );

    step('5 clear returns to live capture');
    JalaBinding.instance.store.clear();
    expect(JalaBinding.instance.store.isViewingImport, isFalse);
    expect(JalaBinding.instance.store.entries, isEmpty);

    step('6 PASS');
  });
}
