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
  });
}
