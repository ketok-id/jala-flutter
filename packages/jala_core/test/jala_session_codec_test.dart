import 'dart:convert';
import 'dart:typed_data';

import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('JalaSessionCodec', () {
    late JalaEventBus bus;
    late JalaStore store;

    setUp(() {
      bus = enabledBus();
      store = JalaStore(bus: bus, maxSubscriptionPayloads: 5);
    });

    tearDown(() async {
      await store.dispose();
      await bus.dispose();
    });

    test('empty store round-trips to an empty session', () {
      final encoded = JalaSessionCodec.encode(store);
      final session = JalaSessionCodec.decode(encoded);
      expect(session.entries, isEmpty);
      expect(session.wsConnections, isEmpty);
      expect(session.version, JalaSessionCodec.currentVersion);
    });

    test('envelope carries the format marker and version', () {
      final encoded = JalaSessionCodec.encode(store);
      final map = Map<String, Object?>.from(
        jsonDecode(encoded) as Map<Object?, Object?>,
      );
      expect(map['format'], 'jala-session');
      expect(map['version'], 1);
      expect(map['exportedAt'], isA<String>());
      expect(map.containsKey('entries'), isTrue);
      expect(map.containsKey('wsConnections'), isTrue);
    });

    test('text/json bodies round-trip', () async {
      emitRequest(bus, 'a', method: 'post', url: 'https://x.dev/p');
      emitResponse(
        bus,
        'a',
        body: CapturedBody.capture(
          '{"ok":true}',
          contentType: 'application/json',
        ),
      );
      await pump();

      final decoded = JalaSessionCodec.decode(JalaSessionCodec.encode(store));
      final entry = decoded.entries.single;
      expect(entry.id, 'a');
      expect(entry.method, 'POST');
      expect(entry.responseBody.kind, BodyKind.json);
      expect(entry.responseBody.text, '{"ok":true}');
    });

    test('image bytes round-trip via base64', () async {
      final imageBytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
      emitRequest(bus, 'img');
      bus.emit(
        NetworkResponseEvent(
          callId: 'img',
          timestamp: DateTime.utc(2026),
          statusCode: 200,
          headers: const <String, String>{},
          body: CapturedBody.image(
            imageBytes,
            originalSize: 64,
            truncated: false,
            contentType: 'image/png',
          ),
          duration: const Duration(milliseconds: 5),
        ),
      );
      await pump();

      final decoded = JalaSessionCodec.decode(JalaSessionCodec.encode(store));
      final entry = decoded.entries.single;
      expect(entry.responseBody.kind, BodyKind.image);
      expect(entry.responseBody.bytes, imageBytes);
      expect(entry.responseBody.contentType, 'image/png');
    });

    test('unicode text round-trips', () async {
      emitRequest(bus, 'u');
      emitResponse(bus, 'u', body: CapturedBody.capture('héllo ✓ 日本語'));
      await pump();

      final decoded = JalaSessionCodec.decode(JalaSessionCodec.encode(store));
      expect(decoded.entries.single.responseBody.text, 'héllo ✓ 日本語');
    });

    test('truncated body round-trips exactly', () async {
      emitRequest(bus, 't');
      emitResponse(
        bus,
        't',
        body: CapturedBody.capture('a' * 100, maxBytes: 10),
      );
      await pump();

      final decoded = JalaSessionCodec.decode(JalaSessionCodec.encode(store));
      final body = decoded.entries.single.responseBody;
      expect(body.kind, BodyKind.truncated);
      expect(body.truncated, isTrue);
      expect(body.originalSize, 100);
      expect(body.text, 'a' * 10);
    });

    test(
      'operationName/Type, mock/replay/throttle fields round-trip',
      () async {
        bus.emit(
          NetworkRequestEvent(
            callId: 'gql',
            timestamp: DateTime.utc(2026),
            method: 'POST',
            uri: Uri.parse('https://api.dev/graphql'),
            headers: const <String, String>{},
            body: CapturedBody.none,
            client: 'graphql',
            replayOf: 'orig-1',
            mockRuleId: 'rule-1',
            operationName: 'GetUser',
            operationType: 'query',
            throttledBy: 'slow3g',
          ),
        );
        await pump();

        final decoded = JalaSessionCodec.decode(
          JalaSessionCodec.encode(store),
        );
        final entry = decoded.entries.single;
        expect(entry.operationName, 'GetUser');
        expect(entry.operationType, 'query');
        expect(entry.mockRuleId, 'rule-1');
        expect(entry.replayOf, 'orig-1');
        expect(entry.throttledBy, 'slow3g');
      },
    );

    test('subscription payloads round-trip; progress is not', () async {
      emitRequest(
        bus,
        's',
        operationName: 'OnMsg',
        operationType: 'subscription',
      );
      emitSubscriptionPayload(bus, 's', seq: 0);
      emitSubscriptionPayload(bus, 's', seq: 1);
      emitProgress(bus, 's', sentBytes: 5, receivedBytes: 10);
      await pump();

      final decoded = JalaSessionCodec.decode(JalaSessionCodec.encode(store));
      final entry = decoded.entries.single;
      expect(entry.payloads, hasLength(2));
      expect(entry.payloadCount, 2);
      expect(entry.progress, isNull, reason: 'transient, never serialized');
    });

    test('ws connections and frames round-trip', () async {
      emitWsConnect(bus, 'ws-a', url: 'wss://x.dev/socket');
      emitWsFrame(bus, 'ws-a', direction: WsDirection.sent, data: 'hi');
      emitWsFrame(bus, 'ws-a', direction: WsDirection.received, data: 'bye');
      emitWsClose(bus, 'ws-a', code: 1000, reason: 'done');
      await pump();

      final decoded = JalaSessionCodec.decode(JalaSessionCodec.encode(store));
      final conn = decoded.wsConnections.single;
      expect(conn.id, 'ws-a');
      expect(conn.uri, Uri.parse('wss://x.dev/socket'));
      expect(conn.status, WsConnectionStatus.closed);
      expect(conn.closeCode, 1000);
      expect(conn.closeReason, 'done');
      expect(conn.frameCount, 2);
      expect(conn.frames, hasLength(2));
      expect(conn.frames.map((f) => f.preview), <String?>['hi', 'bye']);
    });

    test('imported flag round-trips', () async {
      emitRequest(bus, 'imp');
      emitResponse(bus, 'imp');
      await pump();
      // Not imported originally.
      expect(store.byId('imp')!.imported, isFalse);

      final decoded = JalaSessionCodec.decode(JalaSessionCodec.encode(store));
      expect(decoded.entries.single.imported, isFalse);
    });

    group('decode failures', () {
      test('garbage input throws JalaSessionFormatException', () {
        expect(
          () => JalaSessionCodec.decode('not json at all {{{'),
          throwsA(isA<JalaSessionFormatException>()),
        );
      });

      test('valid JSON but wrong format marker throws', () {
        expect(
          () => JalaSessionCodec.decode(
            jsonEncode(<String, Object?>{
              'format': 'something-else',
              'version': 1,
            }),
          ),
          throwsA(isA<JalaSessionFormatException>()),
        );
      });

      test('missing format marker throws', () {
        expect(
          () => JalaSessionCodec.decode(
            jsonEncode(<String, Object?>{'version': 1}),
          ),
          throwsA(isA<JalaSessionFormatException>()),
        );
      });

      test('future (unsupported) version throws', () {
        final future = jsonEncode(<String, Object?>{
          'format': 'jala-session',
          'version': 999,
          'exportedAt': DateTime.now().toUtc().toIso8601String(),
          'entries': <Object?>[],
          'wsConnections': <Object?>[],
        });
        expect(
          () => JalaSessionCodec.decode(future),
          throwsA(isA<JalaSessionFormatException>()),
        );
      });

      test('malformed entry inside an otherwise-valid envelope throws', () {
        final bad = jsonEncode(<String, Object?>{
          'format': 'jala-session',
          'version': 1,
          'exportedAt': DateTime.now().toUtc().toIso8601String(),
          'entries': <Object?>[
            <String, Object?>{'id': 'only-id-present'},
          ],
          'wsConnections': <Object?>[],
        });
        expect(
          () => JalaSessionCodec.decode(bad),
          throwsA(isA<JalaSessionFormatException>()),
        );
      });

      test('non-object top-level JSON throws', () {
        expect(
          () => JalaSessionCodec.decode(jsonEncode(<Object?>[1, 2, 3])),
          throwsA(isA<JalaSessionFormatException>()),
        );
      });

      test('exception carries an informative message', () {
        try {
          JalaSessionCodec.decode('garbage');
          fail('expected JalaSessionFormatException');
        } on JalaSessionFormatException catch (e) {
          expect(e.message, isNotEmpty);
          expect(e.toString(), contains('JalaSessionFormatException'));
        }
      });

      test('oversized input is rejected', () {
        final String huge = 'x' * (JalaSessionCodec.defaultMaxDecodeChars + 1);
        expect(
          () => JalaSessionCodec.decode(huge),
          throwsA(
            isA<JalaSessionFormatException>().having(
              (JalaSessionFormatException e) => e.message,
              'message',
              contains('too large'),
            ),
          ),
        );
      });
    });

    test('headersOnly export strips bodies', () async {
      emitRequest(bus, 'a', method: 'post', url: 'https://x.dev/p');
      emitResponse(
        bus,
        'a',
        body: CapturedBody.capture(
          '{"ok":true}',
          contentType: 'application/json',
        ),
      );
      await pump();

      final decoded = JalaSessionCodec.decode(
        JalaSessionCodec.encode(
          store,
          options: JalaSessionExportOptions.headersOnly,
        ),
      );
      final entry = decoded.entries.single;
      expect(entry.responseBody.kind, BodyKind.none);
      expect(entry.requestBody.kind, BodyKind.none);
    });

    test('stripImages export removes image bytes', () async {
      final imageBytes = Uint8List.fromList(List<int>.generate(16, (i) => i));
      emitRequest(bus, 'img');
      bus.emit(
        NetworkResponseEvent(
          callId: 'img',
          timestamp: DateTime.utc(2026),
          statusCode: 200,
          headers: const <String, String>{},
          body: CapturedBody.image(
            imageBytes,
            originalSize: 16,
            truncated: false,
            contentType: 'image/png',
          ),
          duration: const Duration(milliseconds: 5),
        ),
      );
      await pump();

      final decoded = JalaSessionCodec.decode(
        JalaSessionCodec.encode(
          store,
          options: JalaSessionExportOptions.stripImages,
        ),
      );
      expect(decoded.entries.single.responseBody.kind, BodyKind.none);
    });
  });
}
