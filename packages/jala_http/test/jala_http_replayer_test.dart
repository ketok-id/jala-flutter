import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jala_core/jala_core.dart';
import 'package:jala_http/jala_http.dart';
import 'package:test/test.dart';

import 'support/fake_http_client.dart';

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  tearDown(JalaBinding.resetForTesting);

  group('JalaHttp.wrap + JalaHttpReplayer', () {
    test('wrap registers a replayer', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeHttpClient fake = FakeHttpClient(
        (request) async => jsonStreamedResponse(<String, dynamic>{'ok': true}),
      );

      JalaHttp.wrap(fake);

      expect(JalaBinding.instance.replayRegistry.hasReplayer, isTrue);
    });

    test(
      'replaying an entry issues a new request and the store gains a '
      'new entry with replayOf set, without resending the masked header '
      'or the internal replay-tag header',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        final FakeHttpClient fake = FakeHttpClient(
          (request) async => jsonStreamedResponse(<String, dynamic>{
            'ok': true,
          }),
        );
        final http.Client client = JalaHttp.wrap(fake);

        await client.get(
          Uri.parse('https://api.example.com/users/1'),
          headers: <String, String>{'Authorization': 'Bearer top-secret'},
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
        // wire on replay, and the internal replay-tag header must never
        // leak to the real request either.
        expect(fake.requests, hasLength(2));
        final http.BaseRequest replayedRequest = fake.requests.last;
        final Iterable<String> lowerHeaderNames = replayedRequest.headers.keys
            .map((k) => k.toLowerCase());
        expect(lowerHeaderNames.contains('authorization'), isFalse);
        expect(lowerHeaderNames.contains('x-jala-replay-of'), isFalse);
      },
    );

    test('replaying a JSON request body re-encodes it as bytes', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      final FakeHttpClient fake = FakeHttpClient(
        (request) async => jsonStreamedResponse(<String, dynamic>{'ok': true}),
      );
      final http.Client client = JalaHttp.wrap(fake);

      await client.post(
        Uri.parse('https://api.example.com/users'),
        body: jsonEncode(<String, dynamic>{'name': 'ada'}),
      );
      await pump();

      final NetworkCallEntry original = JalaBinding.instance.store.entries
          .single;
      await JalaBinding.instance.replayRegistry.replay(original);
      await pump();

      expect(fake.requests, hasLength(2));
      // The request that actually reaches the inner client is re-hosted on
      // an upload-progress-tracking proxy (see
      // JalaHttpClient._wrapForUploadProgress), not the original
      // http.Request instance — read the body back via the bytes
      // FakeHttpClient already drained rather than casting to http.Request
      // (and rather than calling `.finalize()` again, which would throw:
      // a request can only be finalized once).
      final List<int> bytes = fake.requestBodies.last;
      expect(jsonDecode(utf8.decode(bytes)), <String, dynamic>{'name': 'ada'});
    });

    test(
      'replaying a call that then throws is swallowed by the replayer',
      () async {
        JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
        int calls = 0;
        final FakeHttpClient fake = FakeHttpClient((request) async {
          calls++;
          if (calls == 1) {
            return jsonStreamedResponse(<String, dynamic>{'ok': true});
          }
          throw Exception('replay network boom');
        });
        final http.Client client = JalaHttp.wrap(fake);

        await client.get(Uri.parse('https://api.example.com/flaky'));
        await pump();
        expect(calls, 1);

        final NetworkCallEntry original = JalaBinding.instance.store.entries
            .single;
        expect(original.status, JalaCallStatus.success);

        // Must not throw, even though the replayed call itself fails.
        await JalaBinding.instance.replayRegistry.replay(original);
        await pump();

        expect(calls, 2);
        final List<NetworkCallEntry> entries = JalaBinding.instance.store
            .entries;
        expect(entries, hasLength(2));
        expect(entries.first.status, JalaCallStatus.error);
        expect(entries.first.replayOf, original.id);
      },
    );
  });
}
