// Store-only Track C smoke (no inspector UI).
// Prints a step marker before each await so hangs are diagnosable.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_dio/jala_dio.dart';

void step(String msg) {
  // ignore: avoid_print
  print('TRACK_C_SMOKE: $msg');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('C2 mock short-circuit store-only', (WidgetTester tester) async {
    step('1 initialize binding');
    JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
    addTearDown(JalaBinding.resetForTesting);

    step('2 attach dio');
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        // Fail fast if mock short-circuit does not resolve.
        sendTimeout: const Duration(seconds: 5),
      ),
    );
    JalaDio.attach(dio);

    step('3 register mock rule');
    JalaBinding.instance.mockRegistry.clear();
    const String ruleId = 'smoke-mock-echo';
    JalaBinding.instance.mockRegistry.add(
      const JalaMockRule(
        id: ruleId,
        name: 'smoke echo get',
        method: 'GET',
        urlPattern: 'https://postman-echo.com/get*',
        action: MockResponse(
          statusCode: 200,
          headers: <String, String>{'content-type': 'application/json'},
          body: '{"jala_smoke":true,"source":"mock"}',
        ),
      ),
    );
    expect(JalaBinding.instance.mockRegistry.rules, hasLength(1));

    step('4 dio.get (should be mocked, no real network)');
    final Stopwatch sw = Stopwatch()..start();
    final Response<dynamic> response = await dio
        .get<dynamic>(
          'https://postman-echo.com/get',
          queryParameters: <String, dynamic>{'smoke': 'track-c'},
        )
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw TimeoutException(
            'dio.get hung — mock short-circuit did not complete',
          ),
        );
    sw.stop();
    step('5 dio.get returned in ${sw.elapsedMilliseconds}ms');

    expect(response.statusCode, 200);
    expect(response.data, isA<Map<String, Object?>>());
    expect((response.data as Map)['jala_smoke'], isTrue);
    expect((response.data as Map)['source'], 'mock');
    expect(sw.elapsedMilliseconds, lessThan(3000));

    step('6 flush store');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();

    step('7 assert store entry');
    final List<NetworkCallEntry> entries = JalaBinding.instance.store.entries;
    expect(entries, isNotEmpty);
    final NetworkCallEntry entry = entries.firstWhere(
      (NetworkCallEntry e) => e.mockRuleId == ruleId,
      orElse: () => throw StateError(
        'no entry with mockRuleId=$ruleId; entries=${entries.map((e) => '${e.uri} mock=${e.mockRuleId}').toList()}',
      ),
    );
    expect(entry.status, JalaCallStatus.success);
    expect(entry.responseBody.text, contains('jala_smoke'));
    expect(entry.client, 'dio');

    step('8 PASS');
  });
}
