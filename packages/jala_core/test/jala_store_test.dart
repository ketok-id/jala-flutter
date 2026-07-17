import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  late JalaEventBus bus;
  late JalaStore store;

  setUp(() {
    bus = enabledBus();
    store = JalaStore(bus: bus, maxEntries: 5);
  });

  tearDown(() async {
    await store.dispose();
    await bus.dispose();
  });

  group('correlation', () {
    test('request event creates a pending entry', () async {
      emitRequest(bus, 'a', method: 'post', url: 'https://x.dev/p');
      await pump();

      expect(store.entries, hasLength(1));
      final entry = store.entries.single;
      expect(entry.id, 'a');
      expect(entry.method, 'POST', reason: 'method must be uppercased');
      expect(entry.uri, Uri.parse('https://x.dev/p'));
      expect(entry.status, JalaCallStatus.pending);
      expect(entry.statusCode, isNull);
      expect(entry.duration, isNull);
    });

    test('response event completes the matching entry', () async {
      emitRequest(bus, 'a');
      emitResponse(
        bus,
        'a',
        statusCode: 201,
        statusMessage: 'Created',
        size: 42,
        duration: const Duration(milliseconds: 77),
        body: CapturedBody.capture(
          '{"ok":true}',
          contentType: 'application/json',
        ),
      );
      await pump();

      final entry = store.byId('a')!;
      expect(entry.status, JalaCallStatus.success);
      expect(entry.statusCode, 201);
      expect(entry.statusMessage, 'Created');
      expect(entry.responseSize, 42);
      expect(entry.duration, const Duration(milliseconds: 77));
      expect(entry.responseBody.kind, BodyKind.json);
      expect(
        entry.responseHeaders,
        containsPair('content-type', 'application/json'),
      );
    });

    test('error event marks entry as error and keeps message', () async {
      emitRequest(bus, 'a');
      bus.emit(
        NetworkErrorEvent(
          callId: 'a',
          timestamp: DateTime.utc(2026),
          errorMessage: 'Connection refused',
          duration: const Duration(milliseconds: 10),
        ),
      );
      await pump();

      final entry = store.byId('a')!;
      expect(entry.status, JalaCallStatus.error);
      expect(entry.errorMessage, 'Connection refused');
      expect(entry.duration, const Duration(milliseconds: 10));
    });

    test('error event with a response keeps status code and body', () async {
      emitRequest(bus, 'a');
      bus.emit(
        NetworkErrorEvent(
          callId: 'a',
          timestamp: DateTime.utc(2026),
          errorMessage: 'Bad response',
          statusCode: 500,
          headers: const {'content-type': 'text/plain'},
          body: CapturedBody.capture('boom', contentType: 'text/plain'),
        ),
      );
      await pump();

      final entry = store.byId('a')!;
      expect(entry.statusCode, 500);
      expect(entry.responseBody.text, 'boom');
    });

    test('cancel event marks entry cancelled', () async {
      emitRequest(bus, 'a');
      bus.emit(NetworkCancelEvent(callId: 'a', timestamp: DateTime.utc(2026)));
      await pump();

      expect(store.byId('a')!.status, JalaCallStatus.cancelled);
    });

    test('response for unknown or evicted id is ignored', () async {
      emitResponse(bus, 'ghost');
      await pump();
      expect(store.entries, isEmpty);
    });

    test('entries are ordered newest first', () async {
      emitRequest(bus, 'a');
      emitRequest(bus, 'b');
      emitRequest(bus, 'c');
      await pump();

      expect(store.entries.map((e) => e.id), ['c', 'b', 'a']);
    });

    test('replayOf from request event lands on the entry', () async {
      emitRequest(bus, 'replayed', replayOf: 'original');
      await pump();
      expect(store.byId('replayed')!.replayOf, 'original');
    });
  });

  group('progress', () {
    test('progress event updates the matching pending entry', () async {
      emitRequest(bus, 'a');
      emitProgress(bus, 'a', sentBytes: 10, sentTotal: 100, receivedBytes: 0);
      await pump();

      final entry = store.byId('a')!;
      expect(entry.status, JalaCallStatus.pending);
      expect(entry.progress, isNotNull);
      expect(entry.progress!.sentBytes, 10);
      expect(entry.progress!.sentTotal, 100);
    });

    test('later progress events replace the earlier one', () async {
      emitRequest(bus, 'a');
      emitProgress(bus, 'a', sentBytes: 10, sentTotal: 100);
      emitProgress(bus, 'a', sentBytes: 100, sentTotal: 100, receivedBytes: 50);
      await pump();

      final entry = store.byId('a')!;
      expect(entry.progress!.sentBytes, 100);
      expect(entry.progress!.receivedBytes, 50);
    });

    test('progress for unknown or evicted id is ignored', () async {
      emitProgress(bus, 'ghost', sentBytes: 1);
      await pump();
      expect(store.entries, isEmpty);
    });
  });

  group('eviction', () {
    test('oldest completed entries are evicted before pending ones', () async {
      // 5 = maxEntries. c1/c2 completed; p1..p3 pending.
      emitRequest(bus, 'c1');
      emitResponse(bus, 'c1');
      emitRequest(bus, 'p1');
      emitRequest(bus, 'c2');
      emitResponse(bus, 'c2');
      emitRequest(bus, 'p2');
      emitRequest(bus, 'p3');
      await pump();
      expect(store.entries, hasLength(5));

      // One over capacity: oldest completed (c1) must go, pendings stay.
      emitRequest(bus, 'p4');
      await pump();
      expect(store.byId('c1'), isNull);
      expect(store.byId('p1'), isNotNull);
      expect(store.entries, hasLength(5));

      // Again: c2 is the next completed to go.
      emitRequest(bus, 'p5');
      await pump();
      expect(store.byId('c2'), isNull);
      expect(store.entries.map((e) => e.id), ['p5', 'p4', 'p3', 'p2', 'p1']);
    });

    test(
      'oldest pending is evicted when no completed entries remain',
      () async {
        for (var i = 1; i <= 6; i++) {
          emitRequest(bus, 'p$i');
        }
        await pump();

        expect(store.entries, hasLength(5));
        expect(store.byId('p1'), isNull, reason: 'p1 is the oldest pending');
        expect(store.byId('p6'), isNotNull);
      },
    );

    test('late response for an evicted id is ignored safely', () async {
      for (var i = 1; i <= 6; i++) {
        emitRequest(bus, 'p$i');
      }
      await pump();
      expect(store.byId('p1'), isNull);

      emitResponse(bus, 'p1');
      await pump();
      expect(store.byId('p1'), isNull);
      expect(store.entries, hasLength(5));
    });
  });

  group('store API', () {
    test('clear removes everything', () async {
      emitRequest(bus, 'a');
      emitRequest(bus, 'b');
      await pump();
      store.clear();
      expect(store.entries, isEmpty);
    });

    test('entries snapshot is unmodifiable', () async {
      emitRequest(bus, 'a');
      await pump();
      expect(() => store.entries.clear(), throwsUnsupportedError);
    });

    test(
      'watch immediately replays the current snapshot to new listeners',
      () async {
        emitRequest(bus, 'a');
        await pump();

        final first = await store.watch.first;
        expect(first.map((e) => e.id), ['a']);
      },
    );

    test('watch emits on every change', () async {
      final snapshots = <List<NetworkCallEntry>>[];
      final sub = store.watch.listen(snapshots.add);

      emitRequest(bus, 'a');
      emitResponse(bus, 'a');
      await pump();
      store.clear();
      await pump();
      await sub.cancel();

      expect(snapshots.first, isEmpty, reason: 'initial snapshot');
      expect(snapshots.last, isEmpty, reason: 'after clear');
      expect(
        snapshots.any((s) => s.any((e) => e.status == JalaCallStatus.success)),
        isTrue,
      );
    });

    test('byId returns null for unknown ids', () {
      expect(store.byId('nope'), isNull);
    });
  });

  group('event bus', () {
    test('emit is a no-op while disabled', () async {
      var enabled = false;
      final gatedBus = JalaEventBus(isEnabled: () => enabled);
      final gatedStore = JalaStore(bus: gatedBus);
      addTearDown(() async {
        await gatedStore.dispose();
        await gatedBus.dispose();
      });

      emitRequest(gatedBus, 'dropped');
      await pump();
      expect(gatedStore.entries, isEmpty);

      enabled = true;
      emitRequest(gatedBus, 'kept');
      await pump();
      expect(gatedStore.entries.map((e) => e.id), ['kept']);
    });
  });

  group('id generator', () {
    test('generates unique, non-empty ids', () {
      final ids = {for (var i = 0; i < 1000; i++) JalaIdGenerator.next()};
      expect(ids, hasLength(1000));
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    });
  });

  group('copyWith', () {
    test('explicit null clears nullable fields, omission keeps them', () {
      final entry = makeEntry(statusCode: 200, errorMessage: 'x');
      final kept = entry.copyWith(method: 'PUT');
      expect(kept.statusCode, 200);
      expect(kept.errorMessage, 'x');

      final cleared = entry.copyWith(statusCode: null, errorMessage: null);
      expect(cleared.statusCode, isNull);
      expect(cleared.errorMessage, isNull);
    });

    test(
      'operationName/operationType: omission keeps, explicit null clears',
      () {
        final entry = makeEntry(
          operationName: 'GetUser',
          operationType: 'query',
        );
        final kept = entry.copyWith(method: 'PUT');
        expect(kept.operationName, 'GetUser');
        expect(kept.operationType, 'query');

        final cleared = entry.copyWith(
          operationName: null,
          operationType: null,
        );
        expect(cleared.operationName, isNull);
        expect(cleared.operationType, isNull);
      },
    );

    test('throttledBy: omission keeps, explicit null clears', () {
      final entry = makeEntry(throttledBy: 'slow3g');
      final kept = entry.copyWith(method: 'PUT');
      expect(kept.throttledBy, 'slow3g');

      final cleared = entry.copyWith(throttledBy: null);
      expect(cleared.throttledBy, isNull);
    });

    test('payloads/payloadCount/imported: omission keeps values', () {
      final entry = makeEntry(
        payloads: [CapturedBody.capture('{"n":0}')],
        payloadCount: 7,
        imported: true,
      );
      final kept = entry.copyWith(method: 'PUT');
      expect(kept.payloads, hasLength(1));
      expect(kept.payloadCount, 7);
      expect(kept.imported, isTrue);
    });
  });

  group('throttledBy', () {
    test('request event with throttledBy lands on the entry', () async {
      emitRequest(bus, 'thr-1', throttledBy: 'slow3g');
      await pump();
      expect(store.byId('thr-1')!.throttledBy, 'slow3g');
    });

    test('request event without throttledBy leaves it null', () async {
      emitRequest(bus, 'plain');
      await pump();
      expect(store.byId('plain')!.throttledBy, isNull);
    });

    test('throttledBy survives the response transition', () async {
      emitRequest(bus, 'thr-2', throttledBy: 'flaky');
      emitResponse(bus, 'thr-2');
      await pump();
      final entry = store.byId('thr-2')!;
      expect(entry.status, JalaCallStatus.success);
      expect(entry.throttledBy, 'flaky');
    });
  });

  group('subscription payloads', () {
    late JalaStore subStore;

    setUp(() {
      subStore = JalaStore(bus: bus, maxSubscriptionPayloads: 3);
    });

    tearDown(() async {
      await subStore.dispose();
    });

    test('payload events accumulate on a pending entry', () async {
      emitRequest(
        bus,
        's',
        operationName: 'OnMsg',
        operationType: 'subscription',
      );
      emitSubscriptionPayload(bus, 's', seq: 0);
      emitSubscriptionPayload(bus, 's', seq: 1);
      await pump();

      final entry = subStore.byId('s')!;
      expect(entry.payloads, hasLength(2));
      expect(entry.payloadCount, 2);
      expect(entry.payloads.first.text, '{"n":0}');
      expect(entry.payloads.last.text, '{"n":1}');
    });

    test('ring cap evicts oldest, payloadCount keeps counting', () async {
      emitRequest(bus, 's');
      for (var i = 0; i < 5; i++) {
        emitSubscriptionPayload(bus, 's', seq: i);
      }
      await pump();

      final entry = subStore.byId('s')!;
      expect(entry.payloadCount, 5, reason: 'total ever observed');
      expect(entry.payloads, hasLength(3), reason: 'ring buffer cap');
      expect(
        entry.payloads.map((p) => p.text),
        ['{"n":2}', '{"n":3}', '{"n":4}'],
        reason: 'oldest payloads fall out first',
      );
    });

    test('payloads for a non-pending entry are ignored', () async {
      emitRequest(bus, 's');
      emitResponse(bus, 's');
      emitSubscriptionPayload(bus, 's', seq: 0);
      await pump();

      final entry = subStore.byId('s')!;
      expect(entry.payloads, isEmpty);
      expect(entry.payloadCount, 0);
    });

    test('payloads for unknown or evicted id are ignored', () async {
      emitSubscriptionPayload(bus, 'ghost');
      await pump();
      expect(subStore.entries, isEmpty);
    });

    test('watch emits on every payload', () async {
      final snapshots = <List<NetworkCallEntry>>[];
      final sub = subStore.watch.listen(snapshots.add);

      emitRequest(bus, 's');
      emitSubscriptionPayload(bus, 's');
      await pump();
      await sub.cancel();

      expect(
        snapshots.last.single.payloadCount,
        1,
        reason: 'payload arrival notifies watchers',
      );
    });
  });

  group('importSession', () {
    JalaSession sessionWith({
      List<NetworkCallEntry> entries = const <NetworkCallEntry>[],
      List<WsConnectionEntry> wsConnections = const <WsConnectionEntry>[],
    }) {
      return JalaSession(
        version: 1,
        exportedAt: DateTime.utc(2026, 7, 16),
        entries: entries,
        wsConnections: wsConnections,
      );
    }

    test('replace (default) swaps out current contents', () async {
      emitRequest(bus, 'live-1');
      emitWsConnect(bus, 'ws-live');
      await pump();

      store.importSession(
        sessionWith(
          entries: [makeEntry(id: 'imp-1'), makeEntry(id: 'imp-2')],
          wsConnections: [makeWsEntry(id: 'ws-imp')],
        ),
      );

      expect(store.entries.map((e) => e.id), ['imp-1', 'imp-2']);
      expect(store.wsConnections.map((e) => e.id), ['ws-imp']);
      expect(store.byId('live-1'), isNull);
    });

    test('append keeps current contents underneath', () async {
      emitRequest(bus, 'live-1');
      await pump();

      store.importSession(
        sessionWith(entries: [makeEntry(id: 'imp-1')]),
        append: true,
      );

      expect(store.entries.map((e) => e.id), ['imp-1', 'live-1']);
      expect(store.byId('live-1')!.imported, isFalse);
      expect(store.byId('imp-1')!.imported, isTrue);
    });

    test('every imported entry is marked imported: true', () {
      store.importSession(
        sessionWith(
          entries: [
            makeEntry(id: 'a'),
            makeEntry(id: 'b', imported: true), // already true stays true
          ],
        ),
      );
      expect(store.entries.every((e) => e.imported), isTrue);
    });

    test(
      'isViewingImport lifecycle: false -> import true -> clear false',
      () {
        expect(store.isViewingImport, isFalse);

        store.importSession(sessionWith(entries: [makeEntry(id: 'a')]));
        expect(store.isViewingImport, isTrue);

        store.clear();
        expect(store.isViewingImport, isFalse);
        expect(store.entries, isEmpty);
      },
    );

    test('append import also sets isViewingImport', () {
      store.importSession(sessionWith(), append: true);
      expect(store.isViewingImport, isTrue);
    });

    test('import notifies watch and watchWs streams', () async {
      final snapshots = <List<NetworkCallEntry>>[];
      final wsSnapshots = <List<WsConnectionEntry>>[];
      final sub = store.watch.listen(snapshots.add);
      final wsSub = store.watchWs.listen(wsSnapshots.add);

      store.importSession(
        sessionWith(
          entries: [makeEntry(id: 'imp-1')],
          wsConnections: [makeWsEntry(id: 'ws-imp')],
        ),
      );
      await pump();
      await sub.cancel();
      await wsSub.cancel();

      expect(snapshots.last.map((e) => e.id), ['imp-1']);
      expect(wsSnapshots.last.map((e) => e.id), ['ws-imp']);
    });

    test('ring-buffer capacity still applies to imported entries', () {
      // store has maxEntries 5.
      store.importSession(
        sessionWith(
          entries: [for (var i = 0; i < 8; i++) makeEntry(id: 'imp-$i')],
        ),
      );
      expect(store.entries, hasLength(5));
    });

    test('live capture continues after an import', () async {
      store.importSession(sessionWith(entries: [makeEntry(id: 'imp-1')]));

      emitRequest(bus, 'live-after');
      await pump();

      expect(store.byId('live-after'), isNotNull);
      expect(store.byId('live-after')!.imported, isFalse);
      expect(
        store.isViewingImport,
        isTrue,
        reason: 'still viewing the import until clear()',
      );
    });
  });

  group('GraphQL metadata', () {
    test('request event with operation fields lands on the entry', () async {
      emitRequest(
        bus,
        'gql-1',
        method: 'post',
        operationName: 'GetUser',
        operationType: 'query',
      );
      await pump();

      final entry = store.byId('gql-1')!;
      expect(entry.operationName, 'GetUser');
      expect(entry.operationType, 'query');
    });

    test('request event without operation fields leaves them null', () async {
      emitRequest(bus, 'plain-1');
      await pump();

      final entry = store.byId('plain-1')!;
      expect(entry.operationName, isNull);
      expect(entry.operationType, isNull);
    });
  });

  group('websocket', () {
    late JalaStore wsStore;

    setUp(() {
      wsStore = JalaStore(
        bus: bus,
        maxEntries: 300,
        maxWsConnections: 3,
        maxWsFramesPerConnection: 4,
      );
    });

    tearDown(() async {
      await wsStore.dispose();
    });

    test('connect event creates a connecting entry', () async {
      emitWsConnect(bus, 'ws-a', url: 'wss://x.dev/socket');
      await pump();

      expect(wsStore.wsConnections, hasLength(1));
      final entry = wsStore.wsConnections.single;
      expect(entry.id, 'ws-a');
      expect(entry.uri, Uri.parse('wss://x.dev/socket'));
      expect(entry.status, WsConnectionStatus.connecting);
      expect(entry.frameCount, 0);
      expect(entry.frames, isEmpty);
    });

    test('first frame promotes a connecting entry to open', () async {
      emitWsConnect(bus, 'ws-a');
      emitWsFrame(bus, 'ws-a', direction: WsDirection.sent, data: 'hi');
      await pump();

      final entry = wsStore.wsById('ws-a')!;
      expect(entry.status, WsConnectionStatus.open);
      expect(entry.frameCount, 1);
      expect(entry.frames.single.direction, WsDirection.sent);
      expect(entry.frames.single.preview, 'hi');
    });

    test('open event promotes a connecting entry to open', () async {
      emitWsConnect(bus, 'ws-a');
      emitWsOpen(bus, 'ws-a');
      await pump();

      final entry = wsStore.wsById('ws-a')!;
      expect(entry.status, WsConnectionStatus.open);
      expect(entry.frameCount, 0, reason: 'no frame observed yet');
    });

    test(
      'open event does not downgrade an already-closed/errored entry',
      () async {
        emitWsConnect(bus, 'ws-a');
        emitWsClose(bus, 'ws-a', code: 1000, reason: 'done');
        emitWsOpen(bus, 'ws-a'); // stale/late event; must be a no-op.
        await pump();

        final entry = wsStore.wsById('ws-a')!;
        expect(entry.status, WsConnectionStatus.closed);
        expect(entry.closeCode, 1000);
      },
    );

    test('open event for unknown or evicted id is ignored', () async {
      emitWsOpen(bus, 'ghost');
      await pump();
      expect(wsStore.wsConnections, isEmpty);
    });

    test('subsequent frames keep an open entry open and accumulate', () async {
      emitWsConnect(bus, 'ws-a');
      emitWsFrame(bus, 'ws-a', data: 'one');
      emitWsFrame(bus, 'ws-a', direction: WsDirection.received, data: 'two');
      await pump();

      final entry = wsStore.wsById('ws-a')!;
      expect(entry.status, WsConnectionStatus.open);
      expect(entry.frameCount, 2);
      expect(entry.frames.map((f) => f.preview), ['one', 'two']);
    });

    test('close event marks entry closed with code/reason', () async {
      emitWsConnect(bus, 'ws-a');
      emitWsClose(bus, 'ws-a', code: 1000, reason: 'done');
      await pump();

      final entry = wsStore.wsById('ws-a')!;
      expect(entry.status, WsConnectionStatus.closed);
      expect(entry.closeCode, 1000);
      expect(entry.closeReason, 'done');
      expect(entry.closedAt, isNotNull);
    });

    test('error event marks entry as error and keeps a message', () async {
      emitWsConnect(bus, 'ws-a');
      emitWsError(bus, 'ws-a', errorMessage: 'boom');
      await pump();

      final entry = wsStore.wsById('ws-a')!;
      expect(entry.status, WsConnectionStatus.error);
      expect(entry.closeReason, 'boom');
      expect(entry.closedAt, isNotNull);
    });

    test('frame/close/error for unknown or evicted id is ignored', () async {
      emitWsFrame(bus, 'ghost');
      emitWsClose(bus, 'ghost');
      emitWsError(bus, 'ghost');
      await pump();
      expect(wsStore.wsConnections, isEmpty);
    });

    test('connections are ordered newest first', () async {
      emitWsConnect(bus, 'a');
      emitWsConnect(bus, 'b');
      await pump();

      expect(wsStore.wsConnections.map((e) => e.id), ['b', 'a']);
    });

    group('frame ring buffer (cap 4)', () {
      test('frames beyond the cap evict the oldest, frameCount keeps '
          'counting', () async {
        emitWsConnect(bus, 'ws-a');
        for (var i = 1; i <= 6; i++) {
          emitWsFrame(bus, 'ws-a', data: 'f$i');
        }
        await pump();

        final entry = wsStore.wsById('ws-a')!;
        expect(entry.frameCount, 6, reason: 'total ever observed');
        expect(entry.frames, hasLength(4), reason: 'ring buffer cap');
        expect(
          entry.frames.map((f) => f.preview),
          ['f3', 'f4', 'f5', 'f6'],
          reason: 'oldest frames fall out first',
        );
      });
    });

    group('connection eviction (cap 3)', () {
      test('oldest-closed connection is evicted before live ones', () async {
        emitWsConnect(bus, 'c1');
        emitWsClose(bus, 'c1');
        emitWsConnect(bus, 'open-1');
        emitWsConnect(bus, 'open-2');
        await pump();
        expect(wsStore.wsConnections, hasLength(3));

        // One over capacity: the closed one (c1) must go first.
        emitWsConnect(bus, 'open-3');
        await pump();
        expect(wsStore.wsById('c1'), isNull);
        expect(wsStore.wsConnections, hasLength(3));
        expect(
          wsStore.wsConnections.map((e) => e.id),
          ['open-3', 'open-2', 'open-1'],
        );
      });

      test('errored connections are treated as terminal too', () async {
        emitWsConnect(bus, 'e1');
        emitWsError(bus, 'e1');
        emitWsConnect(bus, 'open-1');
        emitWsConnect(bus, 'open-2');
        await pump();

        emitWsConnect(bus, 'open-3');
        await pump();
        expect(wsStore.wsById('e1'), isNull);
      });

      test('oldest overall is evicted once no terminal entries remain', () async {
        emitWsConnect(bus, 'p1');
        emitWsConnect(bus, 'p2');
        emitWsConnect(bus, 'p3');
        await pump();
        expect(wsStore.wsConnections, hasLength(3));

        emitWsConnect(bus, 'p4');
        await pump();
        expect(
          wsStore.wsById('p1'),
          isNull,
          reason: 'p1 is the oldest connecting connection',
        );
        expect(wsStore.wsConnections.map((e) => e.id), ['p4', 'p3', 'p2']);
      });
    });

    group('watchWs', () {
      test('immediately replays the current snapshot to new listeners', () async {
        emitWsConnect(bus, 'a');
        await pump();

        final first = await wsStore.watchWs.first;
        expect(first.map((e) => e.id), ['a']);
      });

      test('emits on every change', () async {
        final snapshots = <List<WsConnectionEntry>>[];
        final sub = wsStore.watchWs.listen(snapshots.add);

        emitWsConnect(bus, 'a');
        emitWsFrame(bus, 'a');
        await pump();
        wsStore.clear();
        await pump();
        await sub.cancel();

        expect(snapshots.first, isEmpty, reason: 'initial snapshot');
        expect(snapshots.last, isEmpty, reason: 'after clear');
        expect(
          snapshots.any((s) => s.any((e) => e.status == WsConnectionStatus.open)),
          isTrue,
        );
      });
    });

    group('disabled no-op', () {
      test('WS events are dropped while the bus is disabled', () async {
        var enabled = false;
        final gatedBus = JalaEventBus(isEnabled: () => enabled);
        final gatedStore = JalaStore(bus: gatedBus);
        addTearDown(() async {
          await gatedStore.dispose();
          await gatedBus.dispose();
        });

        emitWsConnect(gatedBus, 'dropped');
        await pump();
        expect(gatedStore.wsConnections, isEmpty);

        enabled = true;
        emitWsConnect(gatedBus, 'kept');
        await pump();
        expect(gatedStore.wsConnections.map((e) => e.id), ['kept']);
      });
    });
  });

  group('WsConnectionEntry copyWith', () {
    test('explicit null clears nullable fields, omission keeps them', () {
      final entry = makeWsEntry(closeCode: 1000, closeReason: 'bye');
      final kept = entry.copyWith(status: WsConnectionStatus.closed);
      expect(kept.closeCode, 1000);
      expect(kept.closeReason, 'bye');

      final cleared = entry.copyWith(closeCode: null, closeReason: null);
      expect(cleared.closeCode, isNull);
      expect(cleared.closeReason, isNull);
    });
  });
}
