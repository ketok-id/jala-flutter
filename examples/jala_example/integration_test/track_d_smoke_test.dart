// Store-only Track D smoke (no inspector UI) — WebSocket + GraphQL.
//
// Network-dependent against two public hosts (wss://ws.postman-echo.com/raw,
// https://countries.trevorblades.com/). Generous timeouts; a connectivity
// failure to either host fails soft via `markTestSkipped` instead of
// failing the suite, mirroring how flaky-host smokes are expected to
// degrade in this repo (see docs/plans/track-d-v0.4.md D5).
//
// Prints a step marker before each await so hangs are diagnosable — same
// convention as track_c_smoke_test.dart.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart' show parseString;
import 'package:gql_exec/gql_exec.dart' as gql_exec;
import 'package:gql_http_link/gql_http_link.dart';
import 'package:gql_link/gql_link.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_graphql/jala_graphql.dart';
import 'package:jala_websocket/jala_websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void step(String msg) {
  // ignore: avoid_print
  print('TRACK_D_SMOKE: $msg');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D2 WS echo connect/frames/close store-only', (
    WidgetTester tester,
  ) async {
    step('1 initialize binding');
    JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
    addTearDown(JalaBinding.resetForTesting);

    step('2 connect wss://ws.postman-echo.com/raw');
    final Uri uri = Uri.parse('wss://ws.postman-echo.com/raw');
    WebSocketChannel raw;
    try {
      raw = WebSocketChannel.connect(uri);
      await raw.ready.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('ws handshake timed out'),
      );
    } on Object catch (e) {
      step('SKIP: could not reach $uri ($e)');
      markTestSkipped('ws.postman-echo.com/raw unreachable: $e');
      return;
    }

    step('3 wrap + listen');
    final WebSocketChannel channel = JalaWebSocketChannel.wrap(raw, uri: uri);
    final StreamSubscription<dynamic> sub = channel.stream.listen((_) {});

    step('4 send 3 text frames');
    for (int i = 1; i <= 3; i++) {
      channel.sink.add('hello jala $i');
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    step('5 close(1000, done)');
    await channel.sink.close(1000, 'done').timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('ws close hung'),
    );
    await sub.cancel();

    step('6 flush store');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();

    step('7 assert WsConnectionEntry');
    final List<WsConnectionEntry> connections =
        JalaBinding.instance.store.wsConnections;
    expect(connections, isNotEmpty);
    final WsConnectionEntry entry = connections.firstWhere(
      (WsConnectionEntry e) => e.uri == uri,
      orElse: () => throw StateError(
        'no WsConnectionEntry for $uri; connections='
        '${connections.map((e) => '${e.uri} status=${e.status}').toList()}',
      ),
    );
    expect(entry.status, WsConnectionStatus.closed);
    expect(entry.closeCode, 1000);
    // 3 sent + at least the echo server's own frames (it typically greets
    // on connect and echoes each send back) — >= 3 is the safe floor if
    // some echoes don't land before close; both directions must appear.
    expect(entry.frameCount, greaterThanOrEqualTo(3));
    expect(
      entry.frames.any((WsFrame f) => f.direction == WsDirection.sent),
      isTrue,
      reason: 'expected at least one sent frame in the ring buffer',
    );
    expect(
      entry.frames.any((WsFrame f) => f.direction == WsDirection.received),
      isTrue,
      reason: 'expected at least one received frame in the ring buffer',
    );

    step('8 PASS');
  });

  testWidgets('D3 GraphQL countries query store-only', (
    WidgetTester tester,
  ) async {
    step('1 initialize binding');
    JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
    addTearDown(JalaBinding.resetForTesting);

    step('2 build link chain');
    final Uri endpoint = Uri.parse('https://countries.trevorblades.com/');
    final Link link = Link.from(<Link>[
      JalaGraphQLLink(endpoint: endpoint),
      HttpLink(endpoint.toString()),
    ]);
    const String source = r'''
      query GetCountry($code: ID!) {
        country(code: $code) {
          name
          emoji
          capital
        }
      }
    ''';
    final gql_exec.Request request = gql_exec.Request(
      operation: gql_exec.Operation(
        document: parseString(source),
        operationName: 'GetCountry',
      ),
      variables: const <String, dynamic>{'code': 'ID'},
    );

    step('3 execute query');
    gql_exec.Response response;
    try {
      response = await link.request(request).first.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('graphql query timed out'),
      );
    } on Object catch (e) {
      step('SKIP: could not reach $endpoint ($e)');
      markTestSkipped('countries.trevorblades.com unreachable: $e');
      return;
    }
    expect(
      response.errors == null || response.errors!.isEmpty,
      isTrue,
      reason: 'unexpected GraphQL errors: ${response.errors}',
    );

    step('4 flush store');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();

    step('5 assert NetworkCallEntry');
    final List<NetworkCallEntry> entries = JalaBinding.instance.store.entries;
    final NetworkCallEntry entry = entries.firstWhere(
      (NetworkCallEntry e) => e.operationName == 'GetCountry',
      orElse: () => throw StateError(
        'no entry with operationName=GetCountry; entries='
        '${entries.map((e) => '${e.operationName}/${e.operationType}').toList()}',
      ),
    );
    expect(entry.operationType, 'query');
    expect(entry.statusCode, 200);
    expect(entry.responseBody.text, contains('Indonesia'));

    step('6 PASS');
  });
}
